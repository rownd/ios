//
//  KeyScanner.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation
import SwiftUI
import CodeScanner

struct KeyScannerView: View {
    var receiveKeyTransfer: (_ url: String) -> Void
    @State private var isPresentingScanner = true
    @State private var scannedCode: String?
    @State private var isTransferringKey = false
    @State private var activeNavSelection = ""

    var body: some View {
        ZStack {
            Color(.systemGray6).edgesIgnoringSafeArea(.all)
            VStack(alignment: .leading, spacing: 10) {
                if let code = scannedCode {

//                    let url = URL(string: code)
//                    if let url = url {
//                        SignInLinks.signInWithLink(url)
//                    }
                    //                NavigationLink("Next page", destination: NextView(scannedCode: code), isActive: .constant(true)).hidden()
                }

                Text("If you have an account attached to another device, you can securely transfer that account data to this device.")
                    .fixedSize(horizontal: false, vertical: true)

                Text("Scan the QR code that is displayed on your other device.")
                    .fixedSize(horizontal: false, vertical: true)

                CodeScannerView(codeTypes: [.qr]) { response in
                    if case let .success(result) = response {
                        scannedCode = result.string
//                        isPresentingScanner = false
                        isTransferringKey = true
                        print(result.string)
                        receiveKeyTransfer(result.string)
                    }
                }
                .cornerRadius(15)
                .padding(.bottom)

                HStack {
                    Spacer()

                    Button(action: {
                        
                    }, label: {
                        Text("Enter code manually")
                    })
                    .padding(.bottom)

                    Spacer()
                }

                NavigationLink(destination: KeyTransferProgress(isShowingProgressView: $isTransferringKey), isActive: $isTransferringKey) { EmptyView() }

            }
            .padding(.horizontal)
        }
    }
}
