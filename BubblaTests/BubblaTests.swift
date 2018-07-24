import XCTest
@testable import Bubbla

extension String: SearchableListProtocol {
    public var textToBeSearched: String { return self }
}

class BubblaTests: XCTestCase {
	
	class MockUrlService: UrlService {
		func dataFromUrl(_ url: URL, session: URLSession, callback: @escaping (Response<Data>) -> Void) {
			let data = try! Data(contentsOf: Bundle(for: type(of: self)).url(forResource: "news", withExtension: "json")!)
			callback(.success(data))
		}
	}
	
	class MockNotificationService: NotificationService {
		func subscribeEndpointArn(_ endpointArn: String, toTopicArn topicArn: String, callback: @escaping (Response<String>) -> Void) {
			callback(.success(topicArn))
		}
		
		func unsubscribe(subscriptionArn: String, callback: @escaping (Response<Bool>) -> Void) {
			callback(.success(true))
		}
		
		func listTopics(callback: @escaping (Response<[Topic]>) -> Void) {
			let topicArns = [
				"arn:aws:sns:eu-central-1:312328711982:bubbla_afrika",
				"arn:aws:sns:eu-central-1:312328711982:bubbla_europa",
				"arn:aws:sns:eu-central-1:312328711982:bubbla_nordamerika",
			]
			callback(.success(topicArns.map { Topic(topicArn: $0) }))
		}
		
		func createEndpointForDeviceToken(_ deviceToken: String, callback: @escaping (Response<String>) -> Void) {
			callback(.success("endpointArn"))
		}
	}
	
	class MockTopicPreferences: TopicPreferences {
		
		var excludeTopicMap = [String:Bool]()
		var subscriptionArnToTopicArnMap = [String:String]()
		
		func excludeTopic(_ topic: Topic) -> Bool {
			return excludeTopicMap[topic.topicArn] ?? false
		}
		
		func makeTopic(_ topic: Topic, excluded: Bool) {
			excludeTopicMap[topic.topicArn] = excluded
		}
		
		func subscriptionArnForTopic(_ topic: Topic) -> String? {
			return subscriptionArnToTopicArnMap[topic.topicArn]
		}
		
		func setSubscriptionArn(_ subscriptionArn: String?, forTopic topic: Topic) {
			subscriptionArnToTopicArnMap[topic.topicArn] = subscriptionArn
		}
	}
	
	var api: _BubblaApi! = nil
	var topicPreferences: TopicPreferences! = nil
	
    override func setUp() {
        super.setUp()
		let notificationService = MockNotificationService()
		topicPreferences = MockTopicPreferences()
		api = _BubblaApi(
			newsSource: .Bubbla,
			urlService: MockUrlService(),
			notificationService: notificationService
		)
    }
    
    func testBubblaNews() {
		var news1 = BubblaNews(title: "", url: URL(string: "http://google.com")!, publicationDate: Date(), category: "Världen",
							   id: "0", imageUrl: nil, facebookUrl: nil, twitterUrl: nil, soundcloudUrl: nil)
        XCTAssertFalse(news1.isRead)
        news1.isRead = true
        XCTAssertTrue(news1.isRead)
        news1.isRead = false
        XCTAssertFalse(news1.isRead)
        XCTAssertEqual(news1.domain, "google.com")
    }
    
    func testNewsFromServer() {
        let expectation = self.expectation(description: "Url Service")
		_BubblaApi(newsSource: .Bubbla, urlService: MockUrlService(), notificationService: MockNotificationService()).news() {
            if case .success(let newsItems) = $0 {
                XCTAssertEqual(newsItems.count, 200)
                let firstItem = newsItems[0]
                XCTAssertEqual(firstItem.title, "Sverigedemokraterna begär återförvisning av propositionen om amnesti för ensamkommande utan asylskäl, kräver en tredjedels stöd i riksdagen och kan innebära att beslut skjuts upp till efter valet")
                XCTAssertEqual(firstItem.category, "Politik")
                XCTAssertEqual(firstItem.url, URL(string: "https://www.expressen.se/nyheter/sd-begar-att-regeringens-lagforslag-om-flyktingamnesti-aterforvisas/"))
                XCTAssertEqual(firstItem.id, "232347bubbla")
                XCTAssertEqual(firstItem.imageUrl, nil)
                XCTAssertEqual(firstItem.domain, "expressen.se")
				
                let categories = BubblaNews.categoriesFromNewsItems(newsItems)
                XCTAssertEqual(categories.count,  15)
				
                XCTAssertEqual(categories[0], "Afrika")
                XCTAssertEqual(categories[1], "Asien")
                
                
            } else {
                XCTAssert(false)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5) {
            error in
            XCTAssertNil(error)
        }
    }
	
	func testNotifications() {
		self.api.registerDevice("deviceToken", topicPreferences: self.topicPreferences) { response in
			self.api.notificationService.listTopics() {
				switch $0 {
				case .success(let topics):
					for topic in topics {
						XCTAssertEqual(self.topicPreferences.subscriptionArnForTopic(topic), topic.topicArn)
					}
				case .error:
					break
				}
			}
		}
	}
	
	func testNotifications3() {
		api.notificationService.listTopics() {
			switch $0 {
			case .success(let topics):
				for topic in topics {
					self.topicPreferences.makeTopic(topic, excluded: true)
					XCTAssertTrue(self.topicPreferences.excludeTopic(topic))
				}
				self.api.registerDevice("deviceToken", topicPreferences: self.topicPreferences) { response in
					self.api.notificationService.listTopics() {
						switch $0 {
						case .success(let topics):
							for topic in topics {
								XCTAssertEqual(self.topicPreferences.subscriptionArnForTopic(topic), nil)
							}
						case .error:
							break
						}
					}
				}
			case .error:
				break
			}
		}
	}
	
	func testNotifications2() {
		api.notificationService.listTopics() {
			switch $0 {
			case .success(let topics):
				for topic in topics {
					XCTAssertFalse(self.topicPreferences.excludeTopic(topic))
					self.topicPreferences.makeTopic(topic, excluded: true)
					XCTAssertTrue(self.topicPreferences.excludeTopic(topic))
					self.topicPreferences.makeTopic(topic, excluded: false)
					XCTAssertFalse(self.topicPreferences.excludeTopic(topic))
				}
			case .error:
				break
			}
		}
	}

    
    func testSearchableList() {
        let items = ["Apa banan clementine", "Mentolcigg banan och mammut"]
        let searchableList = SearchableList(items: items)
        XCTAssert(searchableList.count == 2)
        XCTAssert(searchableList[0] == items[0])
        
        searchableList.updateFilteredItemsToMatchSearchText("apa")
        XCTAssert(searchableList.count == 1)
        XCTAssert(searchableList[0] == items[0])
    
        searchableList.updateFilteredItemsToMatchSearchText("MAMMUT")
        XCTAssert(searchableList.count == 1)
        XCTAssert(searchableList[0] == items[1])
        
        searchableList.updateFilteredItemsToMatchSearchText("apa clementine")
        XCTAssert(searchableList.count == 1)
        
        searchableList.updateFilteredItemsToMatchSearchText("banan")
        XCTAssert(searchableList.count == 2)
        
        searchableList.updateFilteredItemsToMatchSearchText("ey yo")
        XCTAssert(searchableList.count == 0)
        
        
        let emptySearchableList = SearchableList<String>(items: [])
        XCTAssert(emptySearchableList.count == 0)
        emptySearchableList.updateFilteredItemsToMatchSearchText("ey yo")
        XCTAssert(emptySearchableList.count == 0)
    }
	
	func testNewsSourceDistribution() {
		let urls = [
			"https://www.theguardian.com/world/2018/apr/25/peter-madsen-sentenced-life-murdering-kim-wall-submarine",
			"https://www.expressen.se/nyheter/sd-begar-att-regeringens-lagforslag-om-flyktingamnesti-aterforvisas/",
		]
		let newsItems = urls.map {
			BubblaNews(
				title: "",
				url: URL(string: $0)!,
				publicationDate: Date(),
				category: "sverige",
				id: "",
				imageUrl: nil,
				facebookUrl: nil,
				twitterUrl: nil,
				soundcloudUrl: nil
			)
		}
		let newsSourceDistribution = _BubblaApi(newsSource: .Bubbla, urlService: MockUrlService(), notificationService: MockNotificationService()).newsSourceDistributionFromNewsItems(newsItems)
		XCTAssertEqual(newsSourceDistribution.count, 2)
		XCTAssertEqual(newsSourceDistribution[0].count, 1)
		XCTAssertEqual(newsSourceDistribution[0].percentage, 0.5)
		XCTAssertEqual(newsSourceDistribution[1].count, 1)
		XCTAssertEqual(newsSourceDistribution[1].percentage, 0.5)
	}
	
	func testValueCount() {
		let numbers = [1,1,2,3]
		let valueCount = numbers.valueCount
		XCTAssertEqual(valueCount[1]!, 2)
		XCTAssertEqual(valueCount[2]!, 1)
		XCTAssertEqual(valueCount[3]!, 1)
		XCTAssertEqual(valueCount[4], nil)
	}
	
	func testTopics() {
		let topic = Topic(topicArn: "arn:aws:sns:eu-central-1:312328711982:bubbla_afrika")
		XCTAssertEqual(topic.name, "afrika")
		XCTAssertEqual(topic.newsSource, "bubbla")
		
		let strangeTopicName = "arn:aws:sns:eu-central-1:312328711982:ehm"
		let strangeTopic = Topic(topicArn: strangeTopicName)
		XCTAssertEqual(strangeTopic.name, strangeTopicName)
		XCTAssertEqual(strangeTopic.name, strangeTopicName)
	}
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}
