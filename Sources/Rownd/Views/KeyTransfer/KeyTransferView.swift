//
//  KeyTransferView.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/13/22.
//

import Foundation
import SwiftUI
import AVFoundation

struct KeyTransferView : View {

    @Environment(\.presentationMode) var presentationMode

    var parentViewController: UIViewController?
    var setupKeyTransfer: () -> Void
    var receiveKeyTransfer: (_ url: String) -> Void

    @State var appName = "app_name"
    @State private var activeNavSelection: String? = nil
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @ObservedObject var keyState: KeyTransferViewState

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6).edgesIgnoringSafeArea(.all)
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {

                        if store.state.auth.isAuthenticated {
                            Text("Your encryption key is already saved to your iCloud keychain. To view your key or transfer it to another device, tap below.")
                                .fixedSize(horizontal: false, vertical: true)

                            Button(action: {
                                self.setupKeyTransfer()
                                activeNavSelection = "key-code"
                                parentViewController?.bottomSheetController?.grow(toMaximumHeight: true)
                            }, label: {
                                Text("Show encrpytion key")
                                    .frame(minWidth: 0, maxWidth: .infinity)
                            })
                            .modifier(RowndButton())
                        }

                        Text("To sign in to your account using another device, scan the encryption key QR code that's displayed on the other device.")
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 50)
                        Button(action: {
                            switch AVCaptureDevice.authorizationStatus(for: .video) {
                            case .authorized:
                                activeNavSelection = "key-scanner"
                                parentViewController?.bottomSheetController?.grow(toMaximumHeight: true)
                            case .notDetermined:
                                AVCaptureDevice.requestAccess(for: .video) { granted in
                                    if granted {
                                        activeNavSelection = "key-scanner"
                                        parentViewController?.bottomSheetController?.grow(toMaximumHeight: true)
                                    }
                                }
                            case .denied:
                                alertTitle = "Permission denied"
                                alertMessage = "You have previously denied permission to access your device's camera. Open the Settings app and turn on Camera access for this app, then try again."
                                isShowingAlert = true

                                return
                            case .restricted:
                                alertTitle = "Camera restricted"
                                alertMessage = "A policy attached to your device restricts access to the camera."
                                isShowingAlert = true
                            @unknown default:
                                alertTitle = "Oops"
                                alertMessage = "For some reason, we were unable to access your camera."
                                isShowingAlert = true
                            }
                        }, label: {
                            Text("Scan QR code")
                                .frame(minWidth: 0, maxWidth: .infinity)
                        })
                        .modifier(RowndButton())
                        .alert(isPresented: $isShowingAlert) {
                            Alert(
                                title: Text(alertTitle),
                                message: Text(alertMessage),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                        NavigationLink(destination: KeyScannerView(receiveKeyTransfer: receiveKeyTransfer), tag: "key-scanner", selection: $activeNavSelection) { EmptyView() }
                        NavigationLink(destination: KeyCodeView(), tag: "key-code", selection: $activeNavSelection) { EmptyView() }

                        Spacer()

                        HStack {
                            Spacer()

                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }, label: {
                                Text("Cancel")
                                    .padding(.vertical)
                            })

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 30)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        VStack {
                            Text("Encryption key")
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .environmentObject(keyState)
    }
}

struct RowndButton: ViewModifier {
    var backgroundColor: Color = Color(.systemGray5)

    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor)
            .foregroundColor(.primary)
            .clipShape(Capsule())
    }
}

struct KeyTransferView_Previews: PreviewProvider {
    static var previews: some View {
        KeyTransferView(setupKeyTransfer: {
            return
        }, receiveKeyTransfer: { url in
            return
        }, keyState: KeyTransferViewState())
    }
}
