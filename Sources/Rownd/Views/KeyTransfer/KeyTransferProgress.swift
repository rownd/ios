//
//  KeyTransferProgress.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/23/22.
//

import Foundation
import SwiftUI

struct KeyTransferProgress: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var keyState: KeyTransferViewState
    var parentViewController: UIViewController

    @Binding var isShowingProgressView: Bool

    var body: some View {
        ZStack {
            Color(Rownd.config.customizations.sheetBackgroundColor).edgesIgnoringSafeArea(.all)
            VStack(alignment: .leading, spacing: 10) {
                Text("Hang on just a sec. Don't close this window.")
                    .font(.subheadline)
                Spacer()
                if keyState.isReceivingKey {
                    VStack(alignment: .center, spacing: 20) {
                        HStack(alignment: .center) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(2)
                            Spacer()
                        }

                        HStack(alignment: .center) {
                            Spacer()
                            Text("Securely syncing your data to this device...")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .frame(minWidth: 0, maxWidth: .infinity)
                            Spacer()
                        }
                    }.frame(maxHeight: .infinity)

                    Spacer()

                    HStack(alignment: .center) {
                        Spacer()
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }, label: {
                            Text("Cancel")
                        })
                        Spacer()
                    }.padding(.bottom)
                } else if keyState.operationError != nil {
                    VStack(alignment: .center, spacing: 20) {
                        HStack(alignment: .center) {
                            Spacer()
                            Image(systemName: "x.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32, alignment: .center)
                            Spacer()
                        }

                        HStack(alignment: .center) {
                            Spacer()
                            Text("Something went wrong. Please initiate the transfer again.")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .frame(minWidth: 0, maxWidth: .infinity)
                            Spacer()
                        }

                        Button(action: {
                            isShowingProgressView = false
                        }, label: {
                            Text("Try again")
                        })
                    }.frame(maxHeight: .infinity)
                } else {
                    VStack(alignment: .center, spacing: 20) {
                        HStack(alignment: .center) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32, alignment: .center)
                            Spacer()
                        }

                        HStack(alignment: .center) {
                            Spacer()
                            Text("Success!")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .frame(minWidth: 0, maxWidth: .infinity)
                            Spacer()
                        }

                        Button(action: {
                            parentViewController.dismiss(animated: true)
                        }, label: {
                            Text("Finish")
                                .frame(minWidth: 0, maxWidth: .infinity)
                        })
                        .modifier(RowndButton())
                    }.frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                VStack(alignment: .leading) {
                    Text("Signing in with your key")
                        .font(.headline)
                        .padding(.top)
                }
            }
        }
    }
}

