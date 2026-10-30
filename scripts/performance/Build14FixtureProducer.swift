
// Appended ONLY to an isolated detached Build 14 test checkout. Production
// Build 14 sources, its branch, its application and the real iPhone are untouched.
extension N2SimpleInventoryTests {
    func testExportBuild14CompatibilityFixture()throws {
        let output=URL(fileURLWithPath:try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_BUILD14_FIXTURE_OUT"]))
        let original=try source()
        let snapshot=try N2SimpleInventory.activate(snapshot:original,backup:proof(original),
            request:activation(products:[product(),product("16000013",quantity:5),product("16000025",quantity:12)]),catalog:catalog())
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-build14-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:folder)}
        let key=Data(repeating:0xB4,count:32) // published constant, fictional test key only
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:key)
        XCTAssertEqual(try journal.commit(snapshot,expectedRevision:0),1)
        let archive=try N2InventoryBackupCodec.createVerified(snapshot:snapshot,password:password,domain:.demo)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        try FileManager.default.copyItem(at:folder,to:output.appendingPathComponent("journal"))
        try archive.write(to:output.appendingPathComponent("build14-fictional.danperbackup"))
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        let manifest:[String:Any]=["producerSHA":"9b1da6d4cdead4729bcade6843abcbcfc287e870",
            "onlyFictionalData":true,"revision":1,"schema":2,
            "snapshotSHA256":N2SimpleInventory.digest(snapshot),
            "stockSHA256":N2SimpleInventory.digest(try encoder.encode(N2SimpleInventory.read(snapshot))),
            "backupSHA256":N2SimpleInventory.digest(archive)]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys])
            .write(to:output.appendingPathComponent("build14-fixture.json"))
    }
}
