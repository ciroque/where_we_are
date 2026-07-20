// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone
const cookieAttrs =
  ";path=/;max-age=31536000;SameSite=Lax" +
  (location.protocol === "https:" ? ";Secure" : "")

// Persist browser timezone for dead renders / full page loads. LiveView also
// receives it via connect params so the first connected mount converts times
// correctly without requiring a second full reload (important in production).
// IANA names are cookie-safe (letters, digits, _, /, +,-). Do not URI-encode:
// a literal "/" must reach the server for DateTime.now/1 validation.
if (browserTimezone) {
  document.cookie = "tz=" + browserTimezone + cookieAttrs
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken, timezone: browserTimezone}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Persist calendar selections to a cookie when toggled
window.addEventListener("phx:persist_calendars", (e) => {
  document.cookie =
    "selected_calendars=" + encodeURIComponent(e.detail.value) + cookieAttrs
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

