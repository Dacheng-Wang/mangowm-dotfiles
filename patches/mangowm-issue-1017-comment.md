I ran into this too and tracked down why it happens.

In my case, the keyboard is plugged into my monitor's USB hub which powers off during DPMS sleep (same thing happens with Bluetooth keyboards entering sleep mode or when unplugging/replugging a USB keyboard while locked).

When the screen wakes up and the keyboard reconnects:

1. `handle_new_input_device()` (`src/input/device.c`) adds the keyboard to `server.keyboard_group`, but never calls `client_notify_enter()` for the active lock surface.
2. `pointer_process_button_press()` (`src/input/pointer.c`) hits `if (server.session_locked) break;`, so clicking on the lockscreen password box doesn't give it focus either.
3. Unhandled keypresses in `handle_keyboard_key()` are forwarded via `wlr_seat_keyboard_notify_key()`, but since `focused_surface` is NULL, wlroots just drops them.

Switching VT to TTY2 and back to TTY1 "fixes" it because the DRM resume in `handle_output_layout_change()` (`src/manage/monitor.c`) happens to re-focus the lock surface (`client_notify_enter`) after the keyboard has already finished enumerating.

Here is a patch that fixes focus on keyboard hotplug, allows clicking to focus the lock surface, and auto-recovers focus if it's missing when a key/modifier is pressed:

```diff
diff --git a/src/input/device.c b/src/input/device.c
index 100b1fd..cec9d57 100644
--- a/src/input/device.c
+++ b/src/input/device.c
@@ -5,11 +5,14 @@
 #include "mango/input/switch.h"
 #include "mango/input/tablet.h"
 #include "mango/input/touch.h"
+#include "mango/manage/client.h"
+#include "mango/manage/monitor.h"
 #include <wlr/backend/libinput.h>
 #include <wlr/types/wlr_input_device.h>
 #include <wlr/types/wlr_keyboard.h>
 #include <wlr/types/wlr_keyboard_group.h>
 #include <wlr/types/wlr_pointer.h>
+#include <wlr/types/wlr_session_lock_v1.h>
 #include <wlr/types/wlr_switch.h>
 #include <wlr/types/wlr_tablet_pad.h>
 #include <wlr/types/wlr_tablet_tool.h>
@@ -83,4 +86,18 @@ void handle_new_input_device(struct wl_listener *listener, void *data) {
 		!wl_list_empty(&server.standalone_keyboards))
 		caps |= WL_SEAT_CAPABILITY_KEYBOARD;
 	wlr_seat_set_capabilities(server.seat, caps);
+
+	if (device->type == WLR_INPUT_DEVICE_KEYBOARD && server.session_locked) {
+		Monitor *m = server.selected_monitor;
+		if (!m || !m->lock_surface) {
+			wl_list_for_each(m, &server.monitors, link) {
+				if (m->lock_surface)
+					break;
+			}
+		}
+		if (m && m->lock_surface) {
+			client_notify_enter(m->lock_surface->surface,
+								wlr_seat_get_keyboard(server.seat));
+		}
+	}
 }
diff --git a/src/input/keyboard.c b/src/input/keyboard.c
index 6446af0..d5f8c34 100644
--- a/src/input/keyboard.c
+++ b/src/input/keyboard.c
@@ -18,6 +18,7 @@
 #include <wlr/types/wlr_input_device.h>
 #include <wlr/types/wlr_keyboard_group.h>
 #include <wlr/types/wlr_keyboard_shortcuts_inhibit_v1.h>
+#include <wlr/types/wlr_session_lock_v1.h>
 #include <wlr/types/wlr_virtual_keyboard_v1.h>
 #include <wlr/types/wlr_xdg_shell.h>
 #ifdef XWAYLAND
@@ -637,6 +638,24 @@ static Client *keyboard_find_jump_client(Monitor *m, uint32_t keycode) {
 	return NULL;
 }
 
+static void ensure_session_lock_focus(void) {
+	if (!server.session_locked)
+		return;
+	Monitor *m = server.selected_monitor;
+	if (!m || !m->lock_surface) {
+		wl_list_for_each(m, &server.monitors, link) {
+			if (m->lock_surface)
+				break;
+		}
+	}
+	if (m && m->lock_surface &&
+		server.seat->keyboard_state.focused_surface !=
+			m->lock_surface->surface) {
+		client_notify_enter(m->lock_surface->surface,
+							wlr_seat_get_keyboard(server.seat));
+	}
+}
+
 void handle_keyboard_key(struct wl_listener *listener, void *data) {
 	int32_t i;
 	/* This event is raised when a key is pressed or released. */
@@ -778,6 +797,7 @@ void handle_keyboard_key(struct wl_listener *listener, void *data) {
 		if (active != group->keyboard)
 			group->prev_seat_keyboard = active;
 		wlr_seat_set_keyboard(server.seat, group->keyboard);
+		ensure_session_lock_focus();
 		/* Pass unhandled keycodes along to the client. */
 		wlr_seat_keyboard_notify_key(server.seat, event->time_msec,
 									 event->keycode, event->state);
@@ -804,6 +824,7 @@ void handle_keyboard_modifiers(struct wl_listener *listener, void *data) {
 		if (active != group->keyboard)
 			group->prev_seat_keyboard = active;
 		wlr_seat_set_keyboard(server.seat, group->keyboard);
+		ensure_session_lock_focus();
 		/* Send modifiers to the client. */
 		wlr_seat_keyboard_notify_modifiers(server.seat,
 										   &group->keyboard->modifiers);
diff --git a/src/input/pointer.c b/src/input/pointer.c
index 32628e5..60ad6c6 100644
--- a/src/input/pointer.c
+++ b/src/input/pointer.c
@@ -29,6 +29,7 @@
 #include <wlr/types/wlr_pointer_gestures_v1.h>
 #include <wlr/types/wlr_relative_pointer_v1.h>
 #include <wlr/types/wlr_seat.h>
+#include <wlr/types/wlr_session_lock_v1.h>
 #include <wlr/types/wlr_virtual_pointer_v1.h>
 #ifdef XWAYLAND
 #include <wlr/xwayland.h>
@@ -1411,8 +1412,15 @@ bool pointer_process_button_press(struct wlr_pointer_button_event *event) {
 		server.cursor_mode = CurPressed;
 		set_selected_monitor(
 			monitor_at_point(server.cursor->x, server.cursor->y));
-		if (server.session_locked)
+		if (server.session_locked) {
+			if (server.selected_monitor &&
+				server.selected_monitor->lock_surface) {
+				client_notify_enter(
+					server.selected_monitor->lock_surface->surface,
+					wlr_seat_get_keyboard(server.seat));
+			}
 			break;
+		}
 
 		if (switcher_is_active() &&
 			(event->button == BTN_LEFT || event->button == BTN_RIGHT)) {
```

Tested this locally against 0.17.3 and it completely fixes the lockout after wake/suspend.
