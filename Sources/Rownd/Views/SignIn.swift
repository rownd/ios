//
//  SignIn.swift
//  framework
//
//  Created by Matt Hamann on 6/11/22.
//

import SwiftUI

struct SignIn: View {
    @State private var userIdentifier = ""
    
    var body: some View {
        VStack(alignment: .center) {
            HStack() {
                Text("Sign up or sign in")
                    .font(.title)
                    .padding()
                Spacer()
            }
            
            HStack() {
                Text("Email or phone number")
                    .padding(.leading)
                    .font(.system(size: 14))
                Spacer()
            }
            TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: $userIdentifier)
                .padding(.horizontal)
                .background(Color.init(hex: "ffffff"))
            Button("Continue") {
                Text("Continue")
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding()
            .buttonStyle(.borderedProminent)
            
            HStack {
                Text("By continuing, you're agreeing to the terms of service that govern this app and to receive email or text messages for verification purposes.")
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            HStack {
                Text("Powered by Rownd")
                    .padding()
                    .font(.system(size: 14))
                Spacer()
            }
        }
    }
}

struct SignIn_Previews: PreviewProvider {
    static var previews: some View {
        SignIn()
            .previewLayout(.fixed(width: 300, height: 350))
    }
}
