"""Diagnostic fixture + UI timestamps; no App/Core changes or fake approval."""
import os,subprocess
from pathlib import Path

EXTRA='''    func testLargeRosterSearchFindsLastWorkerWithoutRenderingWholeRoster() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo"];app.launch()
        let new=app.buttons["demo-home-new-attention"]
        XCTAssertTrue(new.waitForExistence(timeout:25));new.tap()
        XCTAssertTrue(app.textFields["attention-worker-dni"].waitForExistence(timeout:20))
        tap(app.buttons["attention-browse-workers"],in:app)
        let search=app.textFields["roster-global-search"]
        XCTAssertTrue(search.waitForExistence(timeout:15))
        let rows=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","roster-result-"))
        XCTAssertEqual(rows.count,0)
        XCTAssertTrue(app.buttons["roster-create-worker"].exists)
        search.tap()
        let queryStart=ProcessInfo.processInfo.systemUptime
        search.typeText("PERF 09648")
        let last=app.buttons["roster-result-00009648"]
        XCTAssertTrue(last.waitForExistence(timeout:10),app.debugDescription)
        print("DANPER_LARGE_UI_LAST_SEARCH_MS "+String((ProcessInfo.processInfo.systemUptime-queryStart)*1000))
        XCTAssertEqual(rows.count,1)
        last.tap();waitForWorkerSelectionToSettle(app)
        XCTAssertEqual(app.textFields["attention-worker-dni"].value as? String,"00009648")
        app.buttons["premium-close-attention"].tap()
    }
'''

def instrument(source):
    assert 'DANPER_LARGE_UI_SAVE_MS' not in source
    launch='        app.launch()'
    # Instrument only the save journey: the performance case is unchanged.
    marker='    func testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen() {'
    prefix,body=source.split(marker);assert body.count(launch)==1
    body=body.replace(launch,'        let coldHomeStart=ProcessInfo.processInfo.systemUptime\n'+launch)
    ready='        XCTAssertTrue(new.waitForExistence(timeout:25),app.debugDescription)'
    assert body.count(ready)==1
    body=body.replace(ready,ready+'\n        print("DANPER_LARGE_UI_COLD_HOME_MS "+String((ProcessInfo.processInfo.systemUptime-coldHomeStart)*1000))')
    source=prefix+marker+body
    trigger='        tap(save,in:app)' ;assert source.count(trigger)==1
    confirmed='        XCTAssertTrue(app.staticTexts["Alergias revisadas y guardadas"].waitForExistence(timeout:20),app.debugDescription)'
    assert source.count(confirmed)==1
    source=source.replace(trigger,'        let largeSaveStart=ProcessInfo.processInfo.systemUptime\n'+trigger)
    source=source.replace(confirmed,confirmed+'\n        print("DANPER_LARGE_UI_SAVE_MS "+String((ProcessInfo.processInfo.systemUptime-largeSaveStart)*1000))')
    assert source.rstrip().endswith('}')
    return source.rstrip()[:-1]+EXTRA+'}\n'

if __name__=='__main__':
    harness=Path(__file__).resolve().parents[2];root=Path(os.environ['GITHUB_WORKSPACE'])/'current'
    for name in ['native-ios/NativeTests/N2LargeRosterProfileFixture.swift','scripts/performance/verify_large_ui_products.py']:
        p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((harness/name).read_bytes())
    ui=root/'native-ios/InteractionTests/N2AllergySaveInteractionTests.swift';ui.write_text(instrument(ui.read_text()))
    p=root/'scripts/glass-audit/validate-macos.sh';s=p.read_text()
    old='python3 scripts/performance/test-products.py verify "$DD/Build/Products" "$DANPER_TEST_PROOF"';assert s.count(old)==1
    s=s.replace(old,'python3 scripts/performance/verify_large_ui_products.py verify "$DD/Build/Products" "$DANPER_TEST_PROOF"')
    start=s.index('  run_tests seed-profile 2 ');end=s.index('  git rev-parse HEAD > "$OUT/PROFILE_SOURCE_SHA.txt"',start)
    s=s[:start]+'''  run_tests empty-dashboard 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testEmptyDashboardDoesNotCreateSyntheticSourceOrKey
  run_tests large-seed 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testSeed9648WorkersAnd1005VisitsInEmptyDemo
  run_tests original-fixtures 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests
  run_tests large-invariants-before 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testCaptureCompletePhysicalWorkersAndHistoryBeforeReview
  run_tests large-ui 3 -only-testing:DANPERInteractionTests/N2AllergySaveInteractionTests
  run_tests large-invariants-after 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testVerifyLargeReviewPreservedPhysicalWorkersHistoryAndDraft
'''+s[end:]
    p.write_text(s);subprocess.run(['bash','-n',str(p)],check=True)
