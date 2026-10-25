import Foundation

enum Phase: String { case working, due, resting, ready, away, paused }

// A lid cycle discards the old session only after the screen and login are ready.
struct LidSessionGate {
    private(set) var closed = false
    private(set) var restartPending = false
    mutating func changed(closed value: Bool) {
        closed = value
        if value { restartPending = true }
    }
    mutating func consumeRestart(available: Bool) -> Bool {
        guard restartPending && !closed && available else { return false }
        restartPending = false
        return true
    }
}

struct RestEngine {
    var workDuration: TimeInterval
    var restDuration: TimeInterval
    private(set) var phase: Phase = .working
    private(set) var deadline: Date
    private(set) var awaySince: Date?
    private var savedPhase: Phase = .working
    private var savedRemaining: TimeInterval = 0
    private var pausedPhase: Phase = .working
    private var pausedRemaining: TimeInterval = 0

    init(work: TimeInterval, rest: TimeInterval, now: Date = Date()) {
        workDuration = work; restDuration = rest
        deadline = now.addingTimeInterval(work)
    }
    func remaining(_ now: Date) -> TimeInterval { max(0, deadline.timeIntervalSince(now)) }
    mutating func reset(_ now: Date) {
        phase = .working; deadline = now.addingTimeInterval(workDuration); awaySince = nil
    }
    @discardableResult mutating func tick(_ now: Date) -> Bool {
        if phase == .working && now >= deadline { phase = .due; return true }
        if phase == .resting && now >= deadline { phase = .ready; return true }
        return false
    }
    mutating func startRest(_ now: Date) { phase = .resting; awaySince = nil; deadline = now.addingTimeInterval(restDuration) }
    mutating func snooze(_ now: Date) { phase = .working; deadline = now.addingTimeInterval(300) }
    mutating func pause(_ now: Date) {
        guard phase != .paused else { return }
        pausedPhase = phase; pausedRemaining = remaining(now)
        phase = .paused; deadline = .distantFuture
    }
    mutating func resume(_ now: Date) {
        guard phase == .paused else { return }
        phase = pausedPhase; deadline = now.addingTimeInterval(pausedRemaining)
    }
    mutating func leave(_ now: Date) {
        guard phase != .away && phase != .paused else { return }
        savedPhase = phase; savedRemaining = remaining(now)
        phase = .away; awaySince = now
    }
    mutating func suspendForLid(_ now: Date) {
        // Closing the lid also stops explicit pauses and an in-progress rest.
        phase = .away; awaySince = now
        savedPhase = .working; savedRemaining = workDuration
    }
    mutating func returnFromAway(_ now: Date) {
        guard phase == .away, let start = awaySince else { return }
        let elapsed = max(0, now.timeIntervalSince(start))
        awaySince = nil
        if savedPhase == .resting {
            if elapsed >= savedRemaining { phase = .ready }
            else { phase = .resting; deadline = now.addingTimeInterval(savedRemaining - elapsed) }
        } else if savedPhase == .ready {
            phase = .ready
        } else if elapsed >= restDuration { reset(now) }
        else { phase = savedPhase; deadline = now.addingTimeInterval(savedRemaining) }
    }
}

func runEngineTests() {
    let t = Date(timeIntervalSince1970: 1000)
    var count = 0
    func check(_ result: Bool, _ name: String) {
        guard result else { print("FAIL: \(name)"); exit(1) }
        count += 1; print("PASS: \(name)")
    }
    var e = RestEngine(work: 2400, rest: 600, now: t)
    check(!e.tick(t.addingTimeInterval(2399)), "不到工作截止时间不提醒")
    check(e.tick(t.addingTimeInterval(2400)) && e.phase == .due, "到点进入待休息")
    check(!e.tick(t.addingTimeInterval(2500)) && e.phase == .due, "待休息不重复触发也不自动完成")
    e.reset(t); e.leave(t.addingTimeInterval(1500)); e.returnFromAway(t.addingTimeInterval(1680))
    check(e.phase == .working && e.remaining(t.addingTimeInterval(1680)) == 900, "短暂离开保留剩余时间")
    e.reset(t); e.leave(t.addingTimeInterval(1500)); e.returnFromAway(t.addingTimeInterval(2100))
    check(e.phase == .working && e.remaining(t.addingTimeInterval(2100)) == 2400, "离开满休息时长重置")
    e.startRest(t); check(e.tick(t.addingTimeInterval(600)) && e.phase == .ready, "休息结束等待返回确认")
    check(!e.tick(t.addingTimeInterval(5000)) && e.phase == .ready, "休息结束后不自行计时")
    e.reset(t); e.pause(t.addingTimeInterval(1500))
    check(e.phase == .paused && !e.tick(t.addingTimeInterval(999999)), "暂停计时不会自动恢复或提醒")
    e.resume(t.addingTimeInterval(999999))
    check(e.phase == .working && e.remaining(t.addingTimeInterval(999999)) == 900, "继续计时保留暂停前剩余十五分钟")
    e.startRest(t); e.pause(t.addingTimeInterval(100)); e.resume(t.addingTimeInterval(10000))
    check(e.phase == .resting && e.remaining(t.addingTimeInterval(10000)) == 500, "休息倒计时暂停后也保留剩余时长")
    e.reset(t); _ = e.tick(t.addingTimeInterval(2400)); e.pause(t.addingTimeInterval(2400)); e.resume(t.addingTimeInterval(5000))
    check(e.phase == .due, "待休息状态暂停后仍然等待休息确认")
    e.reset(t); _ = e.tick(t.addingTimeInterval(2400)); e.leave(t.addingTimeInterval(2401)); e.returnFromAway(t.addingTimeInterval(2500))
    check(e.phase == .due, "待休息短暂离开后仍待休息")
    e.startRest(t); e.leave(t.addingTimeInterval(100)); e.returnFromAway(t.addingTimeInterval(700))
    check(e.phase == .ready, "休息过程中睡眠计入休息但不自动工作")
    e.startRest(t); e.leave(t.addingTimeInterval(100)); e.returnFromAway(t.addingTimeInterval(200))
    check(e.phase == .resting && e.remaining(t.addingTimeInterval(200)) == 400, "短暂锁屏后休息倒计时正确")
    e.reset(t); e.snooze(t); check(e.remaining(t) == 300, "稍后提醒延后五分钟")
    var lid = LidSessionGate()
    lid.changed(closed: true)
    e.suspendForLid(t)
    check(e.phase == .away && !e.tick(t.addingTimeInterval(99999)), "合盖彻底停止计时，不触发提醒")
    check(!lid.consumeRestart(available: true), "仍合盖时不能重新计时")
    lid.changed(closed: false)
    check(!lid.consumeRestart(available: false), "开盖但仍锁屏时等待进入系统")
    if lid.consumeRestart(available: true) { e.reset(t.addingTimeInterval(30)) }
    check(e.phase == .working && e.remaining(t.addingTimeInterval(30)) == 2400, "短暂合盖后进入系统也从完整时长开始")
    check(!lid.consumeRestart(available: true), "后续显示器或解锁事件不会重复重置")
    e.pause(t); e.suspendForLid(t)
    check(e.phase == .away && !e.tick(t.addingTimeInterval(99999)), "合盖时手动暂停状态也停止所有定时任务")
    e.startRest(t); e.suspendForLid(t); e.reset(t.addingTimeInterval(10))
    check(e.phase == .working && e.remaining(t.addingTimeInterval(10)) == 2400, "休息期间合盖后开始新一轮使用计时")
    print("\(count) tests passed")
}
