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

    @State var appName = "app_name"
    @State private var isShowingCode = false
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ZStack {
            Color(.systemGray6).edgesIgnoringSafeArea(.all)
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    HubViewControllerWrapper(targetPage: .qrCode, data: "https://rownd.io")
                }
            }

        }
    }
}

