//
//  Created by Dan Federman on 11/9/19.
//  Copyright © 2019 Dan Federman.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS"BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest

@testable import CacheAdvance

final class CacheAdvanceTests: XCTestCase {

    // MARK: Behavior Tests

    func test_isEmpty_returnsTrueWhenCacheIsEmpty() throws {
        let cache = try createCache(overwritesOldMessages: false)

        XCTAssertTrue(try cache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenCacheHasASingleMessage() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
        try cache.append(message: message)

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenOpenedOnCacheThatHasASingleMessage() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(overwritesOldMessages: false)
        try cache.append(message: message)

        let sameCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)

        XCTAssertFalse(try sameCache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenCacheThatDoesNotOverwriteIsFull() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
        try cache.append(message: message)

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenCacheThatOverwritesIsFull() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_messages_canReadEmptyCacheThatDoesNotOverwriteOldestMessages() throws {
        let cache = try createCache(overwritesOldMessages: false)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [])
    }

    func test_messages_canReadEmptyCacheThatOverwritesOldestMessages() throws {
        let cache = try createCache(overwritesOldMessages: true)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [])
    }

    func test_isWritable_returnsTrueWhenStaticHeaderMetadataMatches() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        XCTAssertTrue(try sut.isWritable())
    }

    func test_isWritable_throwsFileCorruptedWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.isWritable()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileCorrupted)
        }
    }

    func test_isWritable_returnsFalseWhenMaximumBytesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(
            sizedToFit: Self.lorumIpsumMessages.dropLast(),
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenOverwritesOldMessagesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: true, zeroOutExistingFile: false)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_append_singleMessageThatFits_canBeRetrieved() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
        try cache.append(message: message)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [message])
    }

    func test_append_singleMessageThatDoesNotFit_throwsError() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false, maximumByteSubtractor: 1)

        XCTAssertThrowsError(try cache.append(message: message)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanCacheCapacity)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, [], "Expected failed first write to result in an empty cache")
    }

    func test_append_singleMessageThrowsIfDoesNotFitAndCacheRolls() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: true, maximumByteSubtractor: 1)

        XCTAssertThrowsError(try cache.append(message: message)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanCacheCapacity)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, [], "Expected failed first write to result in an empty cache")
    }

    func test_append_multipleMessagesCanBeRetrieved() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, Self.lorumIpsumMessages)
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromNonOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: 3)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_dropsLastMessageIfCacheDoesNotRollAndLastMessageDoesNotFit() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertThrowsError(try cache.append(message: "This message won't fit")) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanRemainingCacheSize)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, Self.lorumIpsumMessages)
    }

    func test_append_dropsOldestMessageIfCacheRollsAndLastMessageDoesNotFitAndIsShorterThanOldestMessage() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        // Append a message that is shorter than the first message in Self.lorumIpsumMessages.
        let shortMessage: TestableMessage = "Short message"
        try cache.append(message: shortMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(Self.lorumIpsumMessages.dropFirst()) + [shortMessage])
    }

    func test_append_dropsFirstTwoMessagesIfCacheRollsAndLastMessageDoesNotFitAndIsLargerThanOldestMessage() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        // Append a message that is slightly longer than the first message in Self.lorumIpsumMessages.
        let barelyLongerMessage = TestableMessage(stringLiteral: Self.lorumIpsumMessages[0].value + "hi")
        try cache.append(message: barelyLongerMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(Self.lorumIpsumMessages.dropFirst(2)) + [barelyLongerMessage])
    }

    func test_append_dropsOldMessagesAsNecessary() throws {
        for maximumByteDivisor in stride(from: 1, to: 20, by: 0.1) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in Self.lorumIpsumMessages {
                try cache.append(message: message)
            }

            let messages = try cache.messages()
            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: Self.lorumIpsumMessages, newMessageCount: messages.count), messages)
        }
    }

    func test_append_canWriteMessagesToCacheCreatedByADifferentCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in Self.lorumIpsumMessages.dropLast() {
            try cache.append(message: message)
        }

        let cachedMessages = try cache.messages()
        let secondCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        try secondCache.append(message: Self.lorumIpsumMessages.last!)
        XCTAssertEqual(cachedMessages + [Self.lorumIpsumMessages.last!], try secondCache.messages())
    }

    func test_append_canWriteMessagesToCacheCreatedByADifferentOverridingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in Self.lorumIpsumMessages.dropLast() {
                try cache.append(message: message)
            }

            let cachedMessages = try cache.messages()

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            try secondCache.append(message: Self.lorumIpsumMessages.last!)
            let secondCacheMessages = try secondCache.messages()

            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [Self.lorumIpsumMessages.last!], newMessageCount: secondCacheMessages.count), secondCacheMessages)
        }
    }

    func test_append_canWriteMessagesAfterRetrievingMessages() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in Self.lorumIpsumMessages.dropLast() {
                try cache.append(message: message)
            }

            let cachedMessages = try cache.messages()
            try cache.append(message: Self.lorumIpsumMessages.last!)

            let cachedMessagesAfterAppend = try cache.messages()
            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [Self.lorumIpsumMessages.last!], newMessageCount: cachedMessagesAfterAppend.count), cachedMessagesAfterAppend)
        }
    }

    func test_append_throwsFileNotWritableWhenMaximumBytesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(
            sizedToFit: Self.lorumIpsumMessages.dropLast(),
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.append(message: Self.lorumIpsumMessages.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileNotWritable)
        }
    }

    func test_append_throwsFileNotWritableWhenOverwritesOldMessagesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: true, zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.append(message: Self.lorumIpsumMessages.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileNotWritable)
        }
    }

    func test_messages_canReadMessagesWrittenByADifferentCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        let secondCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentFullCache() throws {
        let cache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1)
        for message in Self.lorumIpsumMessages.dropLast() {
            try cache.append(message: message)
        }
        XCTAssertThrowsError(try cache.append(message: Self.lorumIpsumMessages.last!))

        let secondCache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1, zeroOutExistingFile: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in Self.lorumIpsumMessages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    func test_messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in Self.lorumIpsumMessages {
            try cache.append(message: message)
        }

        let secondCache = try createCache(overwritesOldMessages: true, zeroOutExistingFile: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_cacheThatOverwrites_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true)
            for message in Self.lorumIpsumMessages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    func test_messages_cacheThatDoesNotOverwrites_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: false)
            for message in Self.lorumIpsumMessages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    private static let lorumIpsumMessages: [TestableMessage] = [
        "Lorem ipsum dolor sit amet,",
        "consectetur adipiscing elit.",
        "Etiam sagittis neque massa,",
        "id auctor urna elementum at.",
        "Phasellus sit amet mauris posuere,",
        "aliquet eros nec,",
        "posuere odio.",
        "Ut in neque egestas,",
        "vehicula massa non,",
        "consequat augue.",
        "Pellentesque mattis blandit velit,",
        "ut accumsan velit mollis sed.",
        "Praesent ac vehicula metus.",
        "Praesent eu purus justo.",
        "Maecenas arcu risus,",
        "egestas vitae commodo eu,",
        "gravida non ipsum.",
        "Mauris nec ipsum et lacus rhoncus dictum.",
        "Fusce sagittis magna quis iaculis venenatis.",
        "Nullam placerat odio id nulla porttitor,",
        "ultrices varius nulla varius.",
        "Duis in tellus mauris.",
        "Praesent tristique sem vel nisi gravida hendrerit.",
        "Nullam sit amet vulputate risus,",
        "id tempus tortor.",
        "Vivamus lacus tortor,",
        "varius malesuada metus ut,",
        "sagittis dapibus neque.",
        "Duis fermentum est id justo tempus ornare.",
        "Praesent vulputate ut ligula sit amet gravida.",
        "Integer convallis ipsum vitae purus vulputate lobortis.",
        "Curabitur condimentum ligula eu pharetra suscipit.",
        "Vestibulum imperdiet sem ac eros gravida accumsan.",
        "Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.",
        "Orci varius natoque penatibus et magnis dis parturient montes,",
        "nascetur ridiculus mus.",
        "Nunc at odio dolor.",
        "Curabitur vel risus cursus,",
        "aliquet quam consequat,",
        "egestas metus.",
        "In ut lacus lacus.",
        "Fusce quis mollis velit.",
        "Nullam lobortis urna luctus convallis luctus.",
        "Etiam in tristique lorem.",
        "Donec vulputate odio felis.",
        "Sed tortor enim,",
        "facilisis eget consequat ac,",
        "vehicula a arcu.",
        "Curabitur vehicula magna eu posuere finibus.",
        "Nulla felis ipsum,",
        "dictum id nisi quis,",
        "suscipit laoreet metus.",
        "Nam malesuada nunc ut turpis ullamcorper,",
        "sit amet interdum elit dignissim.",
        "Etiam nec lectus sed dolor pretium accumsan ut at urna.",
        "Nullam diam enim,",
        "hendrerit in sagittis sit amet,",
        "dignissim sit amet erat.",
        "Nam a ex a lectus bibendum convallis id nec urna.",
        "Donec venenatis leo quam,",
        "quis iaculis neque convallis a.",
        "Praesent et venenatis enim,",
        "nec finibus sem.",
        "Sed id lorem non nulla dapibus aliquet vel sed risus.",
        "Aliquam pellentesque elit id dui ullamcorper pellentesque.",
        "In iaculis sollicitudin leo eu bibendum.",
        "Nam condimentum neque sed ultricies sollicitudin.",
        "Sed auctor consequat mollis.",
        "Maecenas hendrerit dignissim leo eget semper.",
        "Aenean et felis sed erat consectetur porttitor.",
        "Vivamus velit tellus,",
        "dictum et leo suscipit,",
        "venenatis sollicitudin neque.",
        "Sed gravida varius viverra.",
        "In rutrum tellus at faucibus volutpat.",
        "Duis bibendum purus eu scelerisque lacinia.",
        "Orci varius natoque penatibus et magnis dis parturient montes,",
        "nascetur ridiculus mus.",
        "Morbi a viverra elit.",
        "Donec egestas felis nunc,",
        "nec tempor magna consequat vulputate.",
        "Vestibulum vel quam magna.",
        "Quisque sed magna ante.",
        "Sed vel lacus vel tellus blandit malesuada nec faucibus sem.",
        "Praesent bibendum bibendum arcu eget ultricies.",
        "Cras elit risus,",
        "semper in varius ut,",
        "aliquam ornare massa.",
        "Pellentesque aliquet nisi in dignissim faucibus.",
        "Curabitur libero lectus,",
        "euismod a eros in,",
        "tincidunt venenatis lectus.",
        "Nunc volutpat pulvinar posuere.",
        "Etiam placerat urna dolor,",
        "accumsan sodales dui maximus vel.",
        "Aenean in velit commodo,",
        "dapibus dui efficitur,",
        "tristique erat.",
        "Quisque pharetra vehicula imperdiet.",
        "In massa orci,",
        "porttitor at maximus vel,",
        "ullamcorper eget purus.",
        "Curabitur pulvinar vestibulum euismod.",
        "Nulla posuere orci ut dapibus commodo.",
        "Etiam pharetra arcu eu ante consectetur,",
        "sed euismod nulla venenatis.",
        "Cras elementum nisl et turpis ultricies,",
        "nec tempor urna iaculis.",
        "Suspendisse a lectus non dolor venenatis bibendum.",
        "Cras mauris tellus,",
        "ultrices a convallis sit amet,",
        "faucibus ut dolor.",
        "Etiam congue tincidunt nunc,",
        "vel ornare ante convallis id.",
        "Fusce egestas lacus id arcu vulputate,",
        "sed fringilla sapien interdum.",
        "Cras ac ipsum vitae neque rhoncus consectetur.",
        "Nunc consequat erat id nulla vulputate,",
        "id malesuada lacus sodales.",
        "Donec aliquam lorem vitae ipsum ullamcorper,",
        "ut hendrerit eros dignissim.",
        "Duis vehicula,",
        "mi ac congue molestie,",
        "est nisl facilisis lectus,",
        "eget finibus ante neque ac tortor.",
        "Mauris eget ante in felis maximus molestie.",
        "Sed ullamcorper aliquam felis,",
        "id molestie eros commodo at.",
        "Etiam a molestie arcu.",
        "Donec mollis viverra neque eget blandit.",
        "Phasellus at felis et tellus aliquam semper ut ut nisl.",
        "Nulla volutpat ultricies lacus,",
        "quis accumsan quam commodo id.",
        "Curabitur sagittis dui nisi,",
        "vitae ullamcorper nulla sagittis id.",
        "Morbi pellentesque fringilla mattis.",
        "Quisque sollicitudin et purus a tempus.",
        "Nunc volutpat sapien sed vulputate dapibus.",
        "Vestibulum fermentum nisi vitae elit fringilla imperdiet.",
        "Phasellus convallis velit quis viverra pellentesque.",
        "Duis sit amet laoreet nunc.",
        "Vestibulum magna odio,",
        "aliquam feugiat urna quis,",
        "interdum condimentum sapien.",
        "Donec varius ipsum non mattis hendrerit.",
        "Fusce a laoreet ligula.",
        "Cras efficitur posuere ante quis ullamcorper.",
        "Donec ut varius quam,",
        "sit amet bibendum ipsum.",
        "Proin molestie,",
        "nulla blandit hendrerit laoreet,",
        "erat sapien mattis odio,",
        "eu egestas erat est id nulla.",
        "Integer pulvinar feugiat justo a mollis.",
        "Maecenas nisi nisl,",
        "lacinia eget convallis eu,",
        "hendrerit sit amet quam.",
        "Vestibulum mattis velit eu sapien maximus pellentesque.",
        "Vivamus venenatis,",
        "ex at condimentum mollis,",
        "odio turpis elementum dui,",
        "sed accumsan odio sem a nibh.",
        "Suspendisse sed tincidunt urna,",
        "quis aliquam risus.",
        "Maecenas vitae lacinia ante.",
        "Nulla quis est mi.",
        "Nunc non maximus nulla.",
        "Phasellus placerat elit ac pretium pharetra.",
        "Nunc nibh dolor,",
        "convallis non ultrices in,",
        "pharetra a massa.",
        "In hac habitasse platea dictumst.",
        "Integer mattis luctus metus,",
        "eget pretium elit semper a.",
        "In interdum congue nibh vel porttitor.",
        "Phasellus eu viverra turpis,",
        "ut molestie metus.",
        "Suspendisse quis eros mollis,",
        "cursus enim in,",
        "malesuada diam.",
        "Nullam in metus vulputate,",
        "finibus nisi ut,",
        "pellentesque tortor.",
        "Mauris rutrum,",
        "lectus ullamcorper elementum dignissim,",
        "orci neque condimentum dolor,",
        "quis tempus ante urna ac dui.",
        "Vestibulum dui elit,",
        "pulvinar at velit non,",
        "maximus semper tortor.",
        "Ut eu neque sit amet nulla aliquet commodo nec fermentum purus.",
        "Mauris ut urna a est sollicitudin condimentum id in enim.",
        "Aliquam porttitor libero id laoreet placerat.",
        "Etiam euismod libero eget risus placerat,",
        "quis egestas sapien lacinia.",
        "Donec eget augue dignissim,",
        "ultrices elit eget,",
        "dictum nibh.",
        "In ultricies risus vel nisi convallis fermentum.",
        "Etiam tempor nisi nulla,",
        "eu pulvinar nisl pretium ut.",
        "Cras ullamcorper enim nisl,",
        "at tempus arcu sagittis quis.",
    ]

    private func requiredByteCount<T: Codable>(for messages: [T]) throws -> UInt64 {
        let encoder = JSONEncoder()
        return try FileHeader.expectedEndOfHeaderInFile
            + messages.reduce(0) { allocatedSize, message in
                let encodableMessage = EncodableMessage(message: message, encoder: encoder)
                let data = try encodableMessage.encodedData()
                return allocatedSize + UInt64(data.count)
        }
    }

    private func createHeaderHandle(
        sizedToFit messages: [TestableMessage] = CacheAdvanceTests.lorumIpsumMessages,
        overwritesOldMessages: Bool,
        maximumByteDivisor: Double = 1,
        maximumByteSubtractor: Bytes = 0,
        version: UInt8 = FileHeader.version,
        zeroOutExistingFile: Bool = true)
        throws
        -> CacheHeaderHandle
    {
        if zeroOutExistingFile {
            FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil)
        }
        return try CacheHeaderHandle(
            forReadingFrom: testFileLocation,
            maximumBytes: Bytes(Double(try requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
            overwritesOldMessages: overwritesOldMessages,
            version: version)
    }

    private func createCache(
        sizedToFit messages: [TestableMessage] = CacheAdvanceTests.lorumIpsumMessages,
        overwritesOldMessages: Bool,
        maximumByteDivisor: Double = 1,
        maximumByteSubtractor: Bytes = 0,
        zeroOutExistingFile: Bool = true)
        throws
        -> CacheAdvance<TestableMessage>
    {
        if zeroOutExistingFile {
            FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil)
        }
        return try CacheAdvance<TestableMessage>(
            fileURL: testFileLocation,
            maximumBytes: Bytes(Double(try requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
            shouldOverwriteOldMessages: overwritesOldMessages)
    }

    private func expectedMessagesInOverwritingCache(
        givenOriginal messages: [TestableMessage],
        newMessageCount: Int)
        -> [TestableMessage]
    {
        Array(messages.dropFirst(messages.count - newMessageCount))
    }

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvanceTests")
}
