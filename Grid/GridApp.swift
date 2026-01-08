//
//  GridApp.swift
//  Grid
//
//  Created by Brendan Rodriguez on 1/6/26.
//

import SwiftUI

@main
struct GridApp: App {
    @StateObject private var scanner = NetworkScanner()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanner)
                .environmentObject(locationManager)
        }
    }
}
