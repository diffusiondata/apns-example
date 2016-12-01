# APNS Example

A working example of an iOS app that both requests and receives push-notifications. Works in concert with `node_client/settopic.js`

![screenshot](/example-screenshot.png?raw=true "Screenshot of APNSExample app")

# Requirements

## To build

* Xcode v8.1 or greater
* Diffusion Apple API v5.9.1 or greater

## To run

* An iOS device running iOS 10.0 or greater
* [Download `Diffusion.framework`](https://developer.reappt.io/clients/apple/) and place in the `Frameworks` folder.
* [Diffusion server](http://download.pushtechnology.com/) v5.9.1 or greater
* A suitably configured [Push Notification Bridge](http://download.pushtechnology.com/docs/latest/manual/html/administratorguide/pushnotifications/pn_bridge.html)

# The process

* Establish either a [Diffusion](http://download.pushtechnology.com/) or [Reappt server](https://reappt.io), and arrange an account with `TOPIC_CONTROL` privilege. Out of the box, account `control` is suitable.

* Clone this repository

* Open the project in Xcode and change the bundle identifier from `com.pushtechnology.example.APNSExample` to that of an AppID configured in your own Apple Developer Account. Ensure the new AppID is configured for Push Notifications.

* Download the SSL certificate related to your AppID, load with the Keychain Access and export the private key within it as `.p12` file. Export with a non-blank password.

* Establish and configure a Push Notification Bridge. See the directory `push_notification_bridge` for details and an example. 

* Configure your Push Notification Bridge to use the APNs servers with the `.p12` private key

* Start the Push Notification Bridge

* Deploy and start the app upon an iOS device. APNs service is unavailable in the simulators.

* Use the Settings app to configure APNSExample to connect to your Diffusion/Reappt server.

* Start APNSExample app and tap on 'Subscribe' and confirm it displays "PNSubscription accepted". 

* Use `settopic.js` to change the value of topic `example/topic` or `example/silent/topic`. The topic updates will display in the app, and be delivered as APNs remote notifications when the app is not running.
