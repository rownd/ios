# Rownd SDK for iOS

The Rownd SDK for iOS provides authentication, account and user profile management, deep linking, encryption and more for native iPhone, iPad, and even macOS applications.

Using the Rownd platform, you can easily bring the same authentication that's on your website to your mobile apps. Or if you only authenticate users on your mobile apps, you can streamline the authentication process using Rownd's passwordless sign-in links, enabling you to seamlessly authenticate users from an app link sent to their email or phone number.

Once a user is authenticated, you can retrieve and update their profile information on the fly using native APIs. Leverage Rownd's pre-built mobile app components to give users profile management tools. Additionally, you can manage encryption of data on-device before sending it back to Rownd or your own backend.

## Installation

In Xcode, select your project file, select the main target, then scroll down to the "frameworks" section to add a package dependency to your project. See the [official documentation](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) for specific steps.

Enter this as the package repository url:

```
https://github.com/rownd/ios.git
```

## Usage

### Initializing the Rownd SDK

In your `AppDelegate` file, call the `Rownd.configure()` method during application launch:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

    Task {
        await Rownd.configure(launchOptions: launchOptions, appKey: "YOUR_API_KEY")
    }

    return true
}
```

After initialization, your app will typically call `Rownd.requestSignIn()` at some point, if the user is not already authenticated. This will display the Rownd interface for authenticating the user. Once they complete the sign-in process, an access token and the user's profile information will be available to your app.

### Handling authentication

Rownd leverages an observeable architecture to expose data to your app. This means that as the Rownd state changes, an app can dynamically update without complicated logic. For example, a view can display different information based on the user's authentication status.

Here's an example SwiftUI view that displays different messages depending on the user's authenticated status:

```swift
import SwiftUI
import Rownd

struct MyView: View {
    @StateObject var authState = Rownd.getInstance().state().subscribe { $0.auth }
    @StateObject var user = Rownd.getInstance().state().subscribe { $0.user.data }

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if authState.current.isAuthenticated {
                        Rownd.signOut()
                    } else {
                        Rownd.requestSignIn()
                    }
                },
                       label: {
                    Text(!authState.current.isAuthenticated ? "Sign in" : "Sign out")
                })
                Spacer()
                if authState.current.isAuthenticated {
                    Button(action: {

                    }, label: {
                        Text(user.current?["first_name"]?.value as? String)
                    })
                }
            }
            .padding(.horizontal)
        }
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
    }
}
```

You can subscribe to any state object that Rownd supports. Here's a list of available states and their structures:

#### .auth

```swift
public struct AuthState {
    public var accessToken: String?     // Current, valid access token for the user (valid for one hour)
    public var isVerifiedUser: Bool?    // Whether the current user has verified at least one identifier (e.g., email)
    public var hasPreviouslySignedIn: Bool    // Whether the app has been previously signed in before
}
```

#### .user

```
public struct UserState {
    public var id: String?                           // The user's ID as known to Rownd
    public var data: Dictionary<String, AnyCodable>  // Contains key/value pairs for the current user based on your Rownd's app config
}
```

### Customizing the UI

While most customizations are handled via the [Rownd dashboard](https://app.rownd.io), there are a few things that have to be customized directly in the SDK.

The `RowndCustomizations` class exists to facilitate these customizations. It provides the following properties that may be subclassed or overridden.

- `sheetBackgroundColor: UIColor` (default: `light: .white`, `dark: .systemGray6`; requires subclassing) - Allows changing the background color underlaying the bottom sheet that appears when signing in, managing the user account, etc.
- `sheetCornerBorderRadius: CGFloat` (default: `25.0`) - Modifies the curvature radius of the bottom sheet corners.
- `loadingAnimation: Lottie.Animation` (default: nil) - Replace Rownd's use of the system default loading spinner (i.e., `UIActivityIndicatorView` or `ProgressView`) with a custom animation. Any animation compatible with [Lottie](https://airbnb.design/lottie/) should work but will be scaled to fit a 1:1 aspect ratio (usually with a `CGRect` frame width/height of `100`)

To apply customizations, we recommend subclassing the `RowndCustomizations` class. Here's an example:

```swift
class AppCustomizations : RowndCustomizations {
    override var sheetBackgroundColor: UIColor {
        return UIColor(red: 31/255, green: 37/255, blue: 80/255, alpha: 1.0)
    }
}

// AppDelegate.swift
import Rownd

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        Rownd.config.customizations = AppCustomizations()   // Apply the customizations

        Task {
            await Rownd.configure(launchOptions: launchOptions, appKey: "YOUR_API_KEY")
        }

        return true
    }
}
```

### Usage within app extensions

It's possible to access the Rownd state from within an app extension, like a widget. You'll need to include the Rownd package in the extension's dependencies and set up an app group for data sharing between the app and the extension. Without the app group, extensions will not be able to sync with your app's authentication state.

Follow these steps to configure your app and extension to work with Rownd:

1. Add an [app group](https://developer.apple.com/documentation/xcode/configuring-app-groups) entitlement to both your app and any extensions that will use Rownd.
   This app group **must** be named like this: `<prefix>.io.rownd.sdk`. For example, if you work at a company with the acme.com domain, your app group might look like this: `com.acme.app.io.rownd.sdk`. Rownd will store its data in this app group. Your app should store data in a separate app group to prevent any collisions.

2. In your app's `AppDelegate` file as well as your extension's entry point, set the app group prefix you defined above via `Rownd.config.appGroupPrefix = "<prefix>"` (e.g., `Rownd.config.appGroupPrefix = "com.acme.app"`)

3. In your extension, call `Rownd.configure()` prior to accessing authentication state. Here's an example:
   ```swift
    Task {
        Rownd.config.appGroupPrefix = "group.rowndexample"
        let rowndState = await Rownd.configure(appKey: "key_pko8eul59xz33hr21jgxvx6s")

        var authStatus: String = "You are not authenticated. ☹️"
        if rowndState.auth.isAuthenticated == true {
            authStatus = "You are authenticated! 😁"
        }
    }
   ```

> NOTE: If you're building widgets that need access to Rownd auth state, you should listen for Rownd auth events and notify `WidgetCenter` that widgets may need updating any time the state changes. That way, they'll re-render while your app is in the foreground and will show an accurate state. Here's a simple example:
>
> ```swift
> import Foundation
> import Combine
> import WidgetKit
> import Rownd
>
> class SomeClass {
>    private var authState = Rownd.getInstance().state().subscribe { $0.auth }
>    private var cancellables = Set<AnyCancellable>()
>
>    init() {
>        self.authState
>            .$current
>            .sink { [weak self] state in
>                WidgetCenter.shared.reloadAllTimelines()
>            }
>            .store(in: &cancellables)
>    }
> }
> ```

### Events

The Rownd SDK emits lifecycle events that you can listen to within your app. These events are primarily useful for detecting more granular aspects of a user's session (e.g., starting to sign in, completing sign-in, updated profile, etc.).

To listen to events, first create a class that conforms to the `RowndEventHandlerDelegate` protocol. It looks something like this:

```swift
import Foundation
import Rownd

class RowndEventHandler: RowndEventHandlerDelegate {
    func handleRowndEvent(_ event: RowndEvent) {
        switch event.event {
        case .signInCompleted:
            let userType = event.data?["user_type"]
            break

        default:
            break
        }
    }
}
```

Next, register the event handler delegate with the Rownd SDK:

```swift
Rownd.addEventHandler(RowndEventHandler())
```

Once the event handler is registered, it will receive events as they occur. The `RowndEvent` object contains the event type and any associated data. The event types are defined in the `RowndEventType` enum.

#### List of events

Here's a list of events that the Rownd SDK emits and the corresponding data that should be present in the event data dictionary. Remember to write your code defensively, as the data dictionary may be missing keys in some cases.

<table>
<tr>
<th>Event</th>
<th>Type</th>
<th>Payload</th>
</tr>
<tr>
<td>User started signing in</td>
<td>.signInStarted</td>
<td>

```javascript
{
  method: "google" | "apple" | "phone" | "email" | "passkey" | etc;
}
```

</td>
</tr>

<tr>
<td>User signed in successfully</td>
<td>.signInCompleted</td>
<td>

```javascript
{
	method: "google" | "apple" | "phone" | "email" | "passkey" | etc,
	user_type: "new_user" | "existing_user"
}
```

</td>
</tr>

<tr>
<td>User sign in failed</td>
<td>.signInFailed</td>
<td>

```javascript
{
  reason: String;
}
```

</td>
</tr>
</table>

## API reference

In addition to the state observable APIs, Rownd provides imperative APIs that you can call to request sign in, get and retrieve user profile information, retrieve a current access token, or encrypt user data with the user's local key.

### Rownd.requestSignIn() -> Void

Opens the Rownd sign-in dialog for authentication.

### Rownd.requestSignIn(RowndSignInOptions(postSignInRedirect: "https://my-domain.com")) -> Void

Opens the Rownd sign-in dialog for authentication, as above. When the user completes the authentication challenge via email or SMS, they'll be redirected to the URL set for `postSignInRedirect`. If this is a [Universal Link](https://developer.apple.com/ios/universal-links/), it will redirect the user back to your app.

### Rownd.requestSignIn(with: RowndSignInHint) -> Void

Requests a sign-in, but with a specific authentication provider (e.g., Sign in with Apple). Rownd treats this information as a hint. If the specified authentication provider is enabled within your Rownd app configuration, it will be honored. If not, Rownd will fall back to the default flow.

Supported values:

- `.appleId` - Prompt user to sign in with their Apple ID

### Rownd.getAccessToken() async throws -> String?

Assuming a user is signed-in, returns a valid access token, refreshing the current one if needed.
If an access token cannot be returned due to a temporary condition (e.g., inaccessible network), this function will `throw`.
If an access token cannot be returned because the refresh token is invalid, `nil` will be returned and the Rownd state
will sign out the user.

Example:

```swift
    do {
        let accessToken = try await Rownd.getAccessToken()
    } catch {
        // Alert the user that they should try again due to some recoverable error
    }
}
```

### Rownd.getAccessToken(\_ token: String) async -> String?

When possible, exchanges a non-Rownd access token for a Rownd access token. This is primarily used in scenarios
where an app is migrating from some other authentication mechanism to Rownd. Using Rownd integrations,
the system will accept a third-party token. If it successfully validates, Rownd will sign-in the user and
return a fresh Rownd access token to the caller.

This API returns `nil` if the token could not be validated and exchanged. If that occurs, it's likely
that the user should sign-in normally via `Rownd.requestSignIn()`.

> NOTE: This API is typically used once. After a Rownd token is available, other tokens should be discarded.
> Example:

```swift
    // Assume `oldToken` was retrieved from some prior authenticator.
    let accessToken = await Rownd.getAccessToken(oldToken)
    if (accessToken != nil) {
        // Navigate to the UI that a user should typically see
    } else {
        Rownd.requestSignIn()
    }
```

### Rownd.user.get() -> Dictionary<String, AnyCodable>

Returns the entire user profile as a dictionary object

### Rownd.user.get<T>(field: String) -> T?

Returns the value of a specific field in the user's data dictionary. `"id"` is a special case that will return the user's ID, even though it's technically not in the dictionary itself.

Your application code is responsible for knowing which type the value should cast to. If the cast fails or the entry doesn't exist, a `nil` value will be returned.

### Rownd.user.set(data: Dictionary<String, AnyCodable>) -> void

Replaces the user's data with that contained in the dictionary. This may overwrite existing values, but must match the schema you defined within your Rownd application dashboard. Any fields that are flagged as `encrypted` will be encrypted on-device prior to storing in Rownd's platform.

Hint: use `AnyCodable.init(value)` to conform your values to the required type.

### Rownd.user.set(field: String, value: AnyCodable) -> void

Sets a specific user profile field to the provided value, overwriting if a value already exists. If the field is flagged as `encrypted`, it will be encrypted on-device prior to storing in Rownd's platform.

Hint: use `AnyCodable.init(value)` to conform your values to the required type.

## Data encryption

As indicated previously, Rownd can automatically assist you in protecting sensitive user data by encrypting it on-device with a user's unique encryption key prior to saving it in Rownd's own platform storage.

When you configure your app within the Rownd platform, you can indicate that it supports on-device encryption. When this flag is set, Rownd will automatically generate a cryptographically secure, unrecoverable encryption key on the user's device after they sign in. The key is stored in the device Keychain and all encryption is handled on the device. The key is never transmitted to Rownd's servers and the Rownd SDK does not provide any APIs to for your code to programmatically retrieve the encryption key.

Only fields that you designate `encrypted` are encrypted on-device prior to storing within Rownd. Some identifying fields like email and phone number do not support on-device encryption at this time, since they are frequently used for indexing purposes.

Of course, all data within the Rownd platform is encrypted at rest on disk and in transit, but this does not afford the same privacy guarantees as data encrypted on a user's local device. For especially sensitive data, we recommend enabling field-level encryption.

> NOTE: Data encrypted on-device will not be accessible by you, the app developer, outside of the context of your app. In other words, your app can use encrypted data in its plaintext (decrypted) form while the user is signed in, but you won't be able to retrieve that data from the Rownd servers in a decrypted form. For data that you choose to encrypt, you should never transmit the plain text value across a network.

In some cases, you may want to encrypt data on-device that you'll send to your own servers for storage. Rownd provides convenience methods to encrypt and decrypt that data with the same user-owned key.

### Rownd.user.encrypt(plaintext: String) throws -> String

Encrypts the provided String `data` using the user's symmetric encryption key and returns the ciphertext as a string. You can encrypt anything that can be represented as a string (e.g., Int, Dictionary, Array, etc), but it's currently up to you to get it into a string format first.

If the encryption fails, an `EncryptionError` will be thrown with a message explaining the failure.

### Rownd.user.decrypt(ciphertext: String) throws -> String

Attempts to decrypt the provided String `data`, returning the plaintext as a string. If the data originated as some other type (e.g., Dictionary), you'll need to decode the data back into its original type.

If the decryption fails, an `EncryptionError` will be thrown with a message explaining the failure.

> NOTE: Encryption is only possible once a user has authenticated. Rownd supports multiple levels of authentication (e.g., guest, unverified, and verified), but the lowest level of authentication must be achieved prior to encrypting or decrypting data. If you need to explicitly check whether encryption is possible at a specific point in time, call `Rownd.user.isEncryptionPossible() -> Bool` prior to calling `encrypt()` or `decrypt()`.
