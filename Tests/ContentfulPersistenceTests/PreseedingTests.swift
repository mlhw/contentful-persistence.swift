//
//  File.swift
//  ContentfulPersistence
//
//  Created by JP Wright on 06.09.17.
//  Copyright © 2017 Contentful GmbH. All rights reserved.
//


@testable import ContentfulPersistence
import Contentful
import XCTest
import CoreData
import CoreLocation

// Regenerate json files with this command
// contentful-utilities sync-to-bundle --spaceId "dqpnpm0n4e75" --accessToken "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13" --output .
class PreseededDatabaseTests: XCTestCase {

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: TestHelpers.managedObjectContext(forMOMInTestBundleNamed: "Test"))
    }()

    var syncManager: SynchronizationManager!

    override func setUp() {
        let entryTypes: [EntryPersistable.Type] = [Author.self, Category.self, Post.self]

        let persistenceModel = PersistenceModel(spaceType: SyncInfo.self, assetType: Asset.self, entryTypes: entryTypes)

        let synchronizationManager = SynchronizationManager(localizationScheme: .default, persistenceStore: self.store, persistenceModel: persistenceModel)

        self.client = Client(spaceId: "dqpnpm0n4e75", accessToken: "95c33f933385aa838825526c5753f3b5a7e59bb45cd6b5d78e15bfeafeef1b13", persistenceIntegration: synchronizationManager)
        self.syncManager = synchronizationManager
    }

    let postPredicate = NSPredicate(format: "id == '1asN98Ph3mUiCYIYiiqwko'")

    func testsCanPreseedDBAndMapLinksToCoreDataRelationships() {
        let directoryName = "PreseedJSONFiles"
        let testBundle = Bundle(for: Swift.type(of: self))

        do {
            try syncManager.seedDBFromJSONFiles(in: directoryName, in: testBundle)
            let post: Post? = try self.store.fetchAll(type: Post.self, predicate: self.postPredicate).first
            XCTAssertNotNil(post)

            XCTAssertNotNil(post?.authors)
            XCTAssertEqual(post?.authors?.count, 1)
            guard let author = post?.authors?.firstObject as? Author else {
                XCTFail("was unable to make relationship")
                return
            }
            XCTAssertNotNil(author.name)
            XCTAssertEqual(author.name, "Lewis Carroll")

            let assets: [Asset] = try self.store.fetchAll(type: Asset.self, predicate: NSPredicate(value: true))
            XCTAssertEqual(assets.count, 6)

            for asset in assets {
                let assetData = SynchronizationManager.bundledData(for: asset, inDirectoryNamed: directoryName, in: testBundle)
                XCTAssertNotNil(assetData)
            }
        } catch let error {
            XCTFail(error.localizedDescription)
        }

    }

    func testsPreseedDBFromMultipageBundleContainsAllEntriesAndAssets() {

        let directoryName = "MultifilePreseedJSONFiles"
        let testBundle = Bundle(for: type(of: self))
        try! syncManager.seedDBFromJSONFiles(in: directoryName, in: testBundle)

        let posts: [Post] = try! self.store.fetchAll(type: Post.self, predicate: NSPredicate(value: true))
        XCTAssertEqual(posts.count, 2)

        let authors: [Author] = try! self.store.fetchAll(type: Author.self, predicate: NSPredicate(value: true))
        XCTAssertEqual(authors.count, 2)

        let categories: [Category] = try! self.store.fetchAll(type: Category.self, predicate: NSPredicate(value: true))
        XCTAssertEqual(categories.count, 2)

        let lewisCarroll: Author = try! self.store.fetchAll(type: Author.self, predicate: NSPredicate(format: "id == '6EczfGnuHCIYGGwEwIqiq2'")).first!
        XCTAssertEqual(lewisCarroll.name, "Lewis Carroll")

        let profilePhoto = lewisCarroll.profilePhoto
        XCTAssertNotNil(profilePhoto)
        XCTAssertEqual(profilePhoto?.urlString, "https://images.contentful.com/dqpnpm0n4e75/2ReMHJhXoAcy4AyamgsgwQ/0a79951064da28107e2d730cecbf6bab/lewis-carroll-1.jpg")

        // Asser that we've cleared all the relationships that were supposed to be resolved.
        XCTAssert(self.syncManager.relationshipsToResolve.isEmpty)
    }
}

class MultiLocalePreseedTests: XCTestCase {

    var syncManager: SynchronizationManager!

    var client: Client!

    lazy var store: CoreDataStore = {
        return CoreDataStore(context: TestHelpers.managedObjectContext(forMOMInTestBundleNamed: "LocalizationTest"))
    }()

    override func setUp() {
        let entryTypes: [EntryPersistable.Type] = [SingleRecord.self, Link.self]

        let persistenceModel = PersistenceModel(spaceType: ComplexSyncInfo.self, assetType: ComplexAsset.self, entryTypes: entryTypes)

        let synchronizationManager = SynchronizationManager(localizationScheme: .all, persistenceStore: self.store, persistenceModel: persistenceModel)

        self.client = Client(spaceId: "smf0sqiu0c5s",
                             accessToken: "14d305ad526d4487e21a99b5b9313a8877ce6fbf540f02b12189eea61550ef34",
                             persistenceIntegration: synchronizationManager)
        self.syncManager = synchronizationManager
    }

    func testPreseededDatabaseHasRecordsForAllLocales() {
        let directoryName = "MultilocalePreseedJSONFiles"
        let testBundle = Bundle(for: type(of: self))
        try! syncManager.seedDBFromJSONFiles(in: directoryName, in: testBundle)

        let records: [SingleRecord] = try! self.store.fetchAll(type: SingleRecord.self,  predicate: NSPredicate(format: "id == '14XouHzspI44uKCcMicWUY'"))

        let englishRecords = records.filter { $0.localeCode == "en-US" }
        let spanishRecords = records.filter { $0.localeCode == "es-MX" }
        // There should be one record per locale: the space has 2 locales.
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(englishRecords.count, 1)
        XCTAssertEqual(spanishRecords.count, 1)
    }
}
