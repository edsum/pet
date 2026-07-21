import XCTest
import Foundation
@testable import DeskPetKit

/// 构造一个"白天中午"的 Date，避免 isNight 影响测试
private func noon(_ daysAgo: Double = 0) -> Date {
    var comp = DateComponents()
    comp.year = 2026; comp.month = 6; comp.day = 15 + Int(daysAgo)
    comp.hour = 12; comp.minute = 0; comp.second = 0
    return Calendar(identifier: .gregorian).date(from: comp)!
}

final class PetStateTests: XCTestCase {

    func test_initial_state() {
        let s = PetState.preview
        XCTAssertEqual(s.level, 1)
        XCTAssertEqual(s.coins, 100)
        XCTAssertEqual(s.stats.health, 100)
    }

    func test_reconcile_decays_over_hours() {
        let now = noon()
        var s = PetState.preview
        s.lastUpdate = now.addingTimeInterval(-3 * 3600)  // 3 小时前（也是白天）

        s.reconcile(now: now)

        // 3 小时非睡觉：energy -6, hunger -9, happiness -6, cleanliness -3
        XCTAssertEqual(s.stats.energy, 80 - 6)
        XCTAssertEqual(s.stats.hunger, 70 - 9)
        XCTAssertEqual(s.stats.happiness, 80 - 6)
        XCTAssertEqual(s.stats.cleanliness, 80 - 3)
    }

    func test_reconcile_sleeping_restores_energy() {
        let now = noon()
        var s = PetState.preview
        s.stats.energy = 30
        s.mood = .sleeping
        s.lastUpdate = now.addingTimeInterval(-3600)

        s.reconcile(now: now)

        XCTAssertEqual(s.stats.energy, 30 + 8)   // +8/h
    }

    func test_reconcile_clamps_at_zero() {
        let now = noon()
        var s = PetState.preview
        s.stats.hunger = 5
        s.lastUpdate = now.addingTimeInterval(-100 * 3600)   // 很久

        s.reconcile(now: now)

        XCTAssertEqual(s.stats.hunger, 0)         // 不会负
    }

    func test_computeMood_picks_hungry() {
        let now = noon()
        var s = PetState.preview
        s.stats.hunger = 10
        s.stats.health = 100
        XCTAssertEqual(s.computeMood(now: now), .hungry)
    }

    func test_computeMood_picks_sick_first() {
        let now = noon()
        var s = PetState.preview
        s.stats.health = 10
        s.stats.hunger = 10
        XCTAssertEqual(s.computeMood(now: now), .sick)    // 健康优先级最高
    }

    func test_addExp_leveling() {
        var s = PetState.preview
        s.addExp(250)             // 第1级升2需100，第2级升3需200 → 剩 -50+200=150? 重算
        // 1->2 消耗100，剩150；2->3 消耗200，不够
        XCTAssertEqual(s.level, 2)
        XCTAssertEqual(s.exp, 150)
        XCTAssertEqual(s.coins, 100 + 30)
    }

    func test_userFed_decreases_coins() {
        var s = PetState.preview
        s.coins = 10
        s.apply(.userFed(.meat))       // price 8
        XCTAssertEqual(s.coins, 2)
        XCTAssertEqual(s.stats.hunger, 70 + 30)
    }

    func test_userFed_blocks_when_no_coins() {
        var s = PetState.preview
        s.coins = 3                    // 不够肉
        s.apply(.userFed(.meat))
        XCTAssertEqual(s.coins, 3)     // 没扣
        XCTAssertEqual(s.stats.hunger, 70)
    }

    func test_rule_engine_charging() {
        var s = PetState.preview
        let env = Environment(isCharging: true)
        EventRuleEngine.shared.apply(environment: env, to: &s)
        XCTAssertEqual(s.mood, .eating)
    }

    func test_rule_engine_low_battery() {
        var s = PetState.preview
        s.stats.energy = 100           // 不被 tired 规则覆盖
        let env = Environment(isCharging: false, batteryLevel: 0.1)
        EventRuleEngine.shared.apply(environment: env, to: &s)
        // 充电规则未命中，低电量规则命中 → tired
        XCTAssertEqual(s.mood, .tired)
    }
}
