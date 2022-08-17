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

    @State var appName = "app_name"
    @State private var isShowingCode = false
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

                        Text("Your encryption key is already saved to your iCloud keychain. To view your key or transfer it to another device, tap below.")
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: {
                            activeNavSelection = "key-code"
                        }, label: {
                            Text("Show encrpytion key")
                                .frame(minWidth: 0, maxWidth: .infinity)
                        })
                        .modifier(RowndButton())

                        Text("To sign in to your account using another device, scan the encryption key QR code that's displayed on the other device.")
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 50)
                        Button(action: {
                            switch AVCaptureDevice.authorizationStatus(for: .video) {
                            case .authorized:
                                isShowingCode = true
                            case .notDetermined:
                                AVCaptureDevice.requestAccess(for: .video) { granted in
                                    if granted {
                                        activeNavSelection = "key-scanner"
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
                        NavigationLink(destination: KeyScannerView(), isActive: $isShowingCode) {
                            EmptyView()
                        }
                        NavigationLink(destination: KeyScannerView(), tag: "key-scanner", selection: $activeNavSelection) { EmptyView() }
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
    }
}

struct RowndButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .clipShape(Capsule())
    }
}

struct KeyTransferView_Previews: PreviewProvider {
    static var previews: some View {
        KeyTransferView(keyState: KeyTransferViewState())
    }
}
