import Foundation
import Testing
import ShareGatherStorage

@Test func sharedItemDeepLinkGeneratesCanonicalURLAndRoundTrips() throws {
    let itemID = try #require(UUID(uuidString: "B4CD262E-6D83-47B0-8218-DBECFAF51D27"))

    let url = SharedItemDeepLink.url(for: itemID)

    #expect(url.absoluteString == "sharegather://bookmark/B4CD262E-6D83-47B0-8218-DBECFAF51D27")
    #expect(SharedItemDeepLink.itemID(from: url) == itemID)
}

@Test(
    arguments: [
        "https://bookmark/B4CD262E-6D83-47B0-8218-DBECFAF51D27",
        "sharegather://saved/B4CD262E-6D83-47B0-8218-DBECFAF51D27",
        "sharegather://bookmark/not-a-uuid",
        "sharegather://bookmark/B4CD262E-6D83-47B0-8218-DBECFAF51D27/extra",
        "sharegather://bookmark/B4CD262E-6D83-47B0-8218-DBECFAF51D27/",
        "sharegather://bookmark/B4CD262E-6D83-47B0-8218-DBECFAF51D27?source=reminder",
        "sharegather://bookmark/B4CD262E-6D83-47B0-8218-DBECFAF51D27#detail",
    ]
)
func sharedItemDeepLinkRejectsNoncanonicalURLs(urlString: String) throws {
    let url = try #require(URL(string: urlString))

    #expect(SharedItemDeepLink.itemID(from: url) == nil)
}

@Test func deepLinkResolveOpensKnownItem() throws {
    let id = try #require(UUID(uuidString: "B4CD262E-6D83-47B0-8218-DBECFAF51D27"))
    let item = makeStubItem(id: id)
    let url = SharedItemDeepLink.url(for: id)

    #expect(SharedItemDeepLink.resolve(url, against: [item]) == .open(id))
}

@Test func deepLinkResolveReturnsUnavailableForUnknownItem() throws {
    let knownID = try #require(UUID(uuidString: "B4CD262E-6D83-47B0-8218-DBECFAF51D27"))
    let referencedID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
    let item = makeStubItem(id: knownID)
    let url = SharedItemDeepLink.url(for: referencedID)

    #expect(SharedItemDeepLink.resolve(url, against: [item]) == .unavailable)
}

@Test func deepLinkResolveReturnsUnavailableForMalformedURL() throws {
    let url = try #require(URL(string: "https://example.com/"))

    #expect(SharedItemDeepLink.resolve(url, against: []) == .unavailable)
}

@Test func deepLinkResolveReturnsUnavailableForEmptyLibrary() throws {
    let id = try #require(UUID(uuidString: "B4CD262E-6D83-47B0-8218-DBECFAF51D27"))
    let url = SharedItemDeepLink.url(for: id)

    #expect(SharedItemDeepLink.resolve(url, against: []) == .unavailable)
}

private func makeStubItem(id: UUID) -> SharedItem {
    SharedItem(id: id, kind: .text, value: "stub")
}

