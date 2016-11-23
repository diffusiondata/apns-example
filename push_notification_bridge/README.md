# Example configuration for Push Notification bridge

`PushNotifications.xml` contains example configuration for the [Push Notification Bridge]. Before deployment it must be configured to reflect your environment.

## Configure the `<server>` element

The governs connectivity to your Diffusion or Reappt instance. Change attributes `url`, `principal` and `credentials` to reflect your environment. Attribute `topicPath` should be unchanged.

## Configure the `<apns>` element

This governs connectivity to Apple's APNs servers. Change attributes `certificate` and `passphrase` to refer to the private key extracted from your certificate retrieved from the Apple Developer portal. The JVM does not allow `.p12` files with a blank passphrase.

Unless you are supporting an app on the iTunes App Store attribute `servers` should be unchanged.