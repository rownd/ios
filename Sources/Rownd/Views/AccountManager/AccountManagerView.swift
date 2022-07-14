//
//  AccountManager.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/13/22.
//

import SwiftUI

struct AccountManager: View {
    
    @StateObject var appConfig = Rownd.getInstance().state().subscribe { $0.appConfig }
    @StateObject var userData = Rownd.getInstance().state().subscribe { $0.user.data }
    
    var body: some View {
        VStack {
            ForEach(appConfig.current.schema?.keys.sorted() ?? [], id: \.self) { field in
                Text(appConfig.current.schema?[field]?.displayName ?? "unknown field")
            }
        }
    }
}


struct AccountManager_Previews: PreviewProvider {
    static var previews: some View {
        AccountManager()
    }
}
