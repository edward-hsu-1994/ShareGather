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
