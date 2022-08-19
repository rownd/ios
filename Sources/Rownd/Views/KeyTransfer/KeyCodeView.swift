//
//  KeyCodeGenerator.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation
import SwiftUI
import WebKit

struct KeyCodeView : View {

    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var keyState: KeyTransferViewState

    @State var appName = "app_name"
    @State private var isShowingCode = false
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

//    @StateObject private var rownd = Rownd.state().subscribe { $0 }

    var body: some View {
        ZStack {
            Color(.systemGray6).edgesIgnoringSafeArea(.all)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your encryption key is automatically saved in your iCloud keychain. To sign in on another device, scan the QR code below with the new device.")

                    VStack(alignment: .center) {
                        HubViewControllerWrapper(targetPage: .qrCode, data: "https://rownd.io/#\(keyState.key)")
                            .frame(maxHeight: .infinity)
                    }
                    .padding()

                    Button(action: {

                    }, label: {
                        HStack {
                            Text("Copy to clipboard")
                            Image(systemName: "square.on.square")
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)

                    })
                    .modifier(RowndButton())

                    Text("You can also copy your account's secret encryption key in case you need to recover it later. Be sure to store it in a safe, secure location.")
                }

            }
            .padding()
        }
    }
}

