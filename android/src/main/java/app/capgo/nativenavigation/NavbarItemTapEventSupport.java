package app.capgo.nativenavigation;

import com.getcapacitor.JSObject;

/** Fields for the `navbarItemTap` listener payload. */
public final class NavbarItemTapEventSupport {

    private NavbarItemTapEventSupport() {}

    public static NavbarItemTapPayload leadingLeft(String id, String title) {
        return new NavbarItemTapPayload(id, title, "left");
    }

    public static void apply(JSObject event, String id, String title, String placement) {
        apply(event, new NavbarItemTapPayload(id, title, placement));
    }

    public static void apply(JSObject event, NavbarItemTapPayload payload) {
        event.put("id", payload.id);
        event.put("title", payload.title);
        event.put("placement", payload.placement);
    }

    public static final class NavbarItemTapPayload {

        public final String id;
        public final String title;
        public final String placement;

        public NavbarItemTapPayload(String id, String title, String placement) {
            this.id = id;
            this.title = title;
            this.placement = placement;
        }
    }
}
