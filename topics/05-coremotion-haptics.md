<h3>5.1 CoreMotion 总览：四个数据源 + 一个融合传感器</h3>

<p>iOS 设备的运动子系统由 <code>CMMotionManager</code> 统一暴露，背后挂着四类原始/融合数据：</p>

<table>
<thead><tr><th>API</th><th>来源</th><th>典型用途</th><th>是否融合</th></tr></thead>
<tbody>
<tr><td><code>accelerometerData</code></td><td>加速度计</td><td>原始 g 力（含重力）、抖动检测</td><td>否</td></tr>
<tr><td><code>gyroData</code></td><td>陀螺仪</td><td>原始三轴角速度 (rad/s)</td><td>否</td></tr>
<tr><td><code>magnetometerData</code></td><td>磁力计</td><td>原始磁场 (μT)、未校准</td><td>否</td></tr>
<tr><td><code>deviceMotion</code></td><td>传感器融合</td><td>姿态、重力分离、用户加速度、heading</td><td>是（推荐）</td></tr>
</tbody>
</table>

<p><strong>结论：除非做信号处理/校准研究，<code>deviceMotion</code> 几乎是唯一正确选择</strong>——CoreMotion 已经做完互补滤波/卡尔曼，把重力从加速度里剥离出来，并保证 attitude 数值稳定。直接吃 raw accelerometer 的代码 99% 都在重新造轮子。参考 WWDC 2012 #524 <em>Understanding Core Motion</em>、WWDC 2017 #704 <em>What's New in CoreMotion</em>。</p>

<h3>5.2 CMDeviceMotion 字段详解</h3>

<ul>
<li><code>attitude: CMAttitude</code>——roll / pitch / yaw（弧度）+ <code>rotationMatrix</code> + <code>quaternion</code>。<code>multiply(byInverseOf:)</code> 可把姿态归零到任意参考点。</li>
<li><code>gravity: CMAcceleration</code>——单位 g（≈9.81 m/s²），表示当前重力方向在设备坐标系的投影，<code>atan2(gravity.x, gravity.y)</code> 就是设备绕 z 轴的倾斜角。</li>
<li><code>userAcceleration: CMAcceleration</code>——已减去重力的"用户施加的加速度"，单位 g。摇一摇/计步基础信号。</li>
<li><code>rotationRate: CMRotationRate</code>——已扣除偏置的角速度（vs raw <code>gyroData</code>）。</li>
<li><code>magneticField: CMCalibratedMagneticField</code>——校准后的磁场 + <code>accuracy</code> 枚举。</li>
<li><code>heading: Double</code>（iOS 11+）——0–360°，相对参考系。需要 reference frame 启用 magnetic/true north 才有意义。</li>
<li><code>sensorLocation</code>（iOS 14+）——区分 iPhone 本机与外接（如 AirPods）传感器。</li>
</ul>

<h3>5.3 Reference Frames：选错北方就全错</h3>

<table>
<thead><tr><th>Frame</th><th>x 轴</th><th>是否需磁力计</th><th>用法</th></tr></thead>
<tbody>
<tr><td><code>xArbitraryZVertical</code></td><td>启动瞬间设备朝向</td><td>否</td><td>视差/摇杆，无地理需求</td></tr>
<tr><td><code>xArbitraryCorrectedZVertical</code></td><td>同上 + 磁力计校漂</td><td>是</td><td>长时间运行，需姿态稳定</td></tr>
<tr><td><code>xMagneticNorthZVertical</code></td><td>磁北</td><td>是</td><td>AR、罗盘</td></tr>
<tr><td><code>xTrueNorthZVertical</code></td><td>真北（需 GPS）</td><td>是 + Location 权限</td><td>地图导航、星图</td></tr>
</tbody>
</table>

<p>启动前先用 <code>CMMotionManager.availableAttitudeReferenceFrames()</code> 检查；选 true north 时若用户拒绝定位会静默降级到 magnetic north，需要 <code>CMAttitude.referenceFrame</code> 回读确认。</p>

<h3>5.4 更新频率与电量</h3>

<p><code>deviceMotionUpdateInterval</code> 单位秒。常用档位：</p>

<ul>
<li><strong>1.0 / 60 ≈ 0.0167s（60Hz）</strong>——UI 视差、滚动联动，绝大多数场景够用，与 ProMotion 之外的屏幕同步。</li>
<li><strong>1.0 / 120（120Hz）</strong>——ProMotion (iPhone 13 Pro+) 上游戏/精细 AR；同时记得把 CADisplayLink 也调到 120。</li>
<li><strong>0.1（10Hz）</strong>——计步/朝向类，省电。</li>
<li><strong>0.01（100Hz）</strong>——动作识别（挥拍、摇晃）。</li>
</ul>

<blockquote><p>实测 60Hz <code>deviceMotion</code> 在 iPhone 15 Pro 上约 1–2% 持续 CPU；120Hz 翻倍。后台运行须开 <code>UIBackgroundModes</code>，且仅 fitness 类 entitlement 通过。</p></blockquote>

<h3>5.5 生命周期与权限</h3>

<ol>
<li><code>Info.plist</code> 加 <code>NSMotionUsageDescription</code>（"用于实现倾斜视差与播放器交互"）。iOS 13+ 用户可在隐私设置撤回，<code>CMSensorRecorder.isAuthorizedForRecording()</code> / <code>CMMotionActivityManager.authorizationStatus()</code> 可查。</li>
<li>app 进 background 后 <code>deviceMotion</code> 被 OS 自动暂停，回 foreground 不需手动重启（updates 仍在排队），但 reference frame 可能漂移；建议在 <code>scenePhase == .active</code> 时 stop+start 重置。</li>
<li><code>CMMotionManager</code> <strong>整个 app 应当只持有一个实例</strong>——多实例会让底层重复打开传感器，电量翻倍且数据可能不一致。Apple 文档明确警告。</li>
</ol>

<h3>5.6 桥接到 SwiftUI：三种模式对比</h3>

<table>
<thead><tr><th>模式</th><th>API</th><th>优点</th><th>缺点</th></tr></thead>
<tbody>
<tr><td>Pull (Timer)</td><td><code>startDeviceMotionUpdates()</code> + <code>Timer</code> 读 <code>deviceMotion</code></td><td>简单</td><td>抖动、容易掉帧</td></tr>
<tr><td>Push</td><td><code>startDeviceMotionUpdates(to:withHandler:)</code></td><td>系统驱动，时序准</td><td>handler 在指定 queue，注意 main hop</td></tr>
<tr><td>AsyncStream</td><td>用 push 包装 <code>AsyncStream</code></td><td>结构化并发、自然 cancel</td><td>需要桥接代码</td></tr>
</tbody>
</table>

<h3>5.7 标准 ObservableObject 封装（iOS 17+）</h3>

<pre><code class="language-swift">import CoreMotion
import SwiftUI

@MainActor
final class MotionStore: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    @Published var yaw: Double = 0
    @Published var gravity: CMAcceleration = .init(x: 0, y: -1, z: 0)

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    init() {
        queue.name = "com.anycast.motion"
        queue.qualityOfService = .userInteractive
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.startDeviceMotionUpdates(
            using: .xArbitraryCorrectedZVertical,
            to: queue
        ) { [weak self] motion, error in
            guard let self, let m = motion else { return }
            Task { @MainActor in
                self.roll = m.attitude.roll
                self.pitch = m.attitude.pitch
                self.yaw = m.attitude.yaw
                self.gravity = m.gravity
            }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
    deinit { manager.stopDeviceMotionUpdates() }
}
</code></pre>

<h3>5.8 AsyncStream 现代封装（iOS 17+）</h3>

<pre><code class="language-swift">extension CMMotionManager {
    func deviceMotionStream(
        interval: TimeInterval = 1.0 / 60.0,
        frame: CMAttitudeReferenceFrame = .xArbitraryCorrectedZVertical
    ) -> AsyncStream<CMDeviceMotion> {
        AsyncStream { continuation in
            self.deviceMotionUpdateInterval = interval
            let q = OperationQueue()
            q.qualityOfService = .userInteractive
            self.startDeviceMotionUpdates(using: frame, to: q) { motion, _ in
                if let motion { continuation.yield(motion) }
            }
            continuation.onTermination = { @Sendable _ in
                self.stopDeviceMotionUpdates()
            }
        }
    }
}

struct ParallaxCard: View {
    @State private var offset: CGSize = .zero
    let manager = CMMotionManager()
    var body: some View {
        Image("artwork").resizable().offset(offset)
            .task {
                for await m in manager.deviceMotionStream() {
                    offset = CGSize(width: m.attitude.roll * 18,
                                    height: -m.attitude.pitch * 18)
                }
            }
    }
}
</code></pre>

<h3>5.9 实战：tilt-driven parallax 卡片（iOS 17+）</h3>

<pre><code class="language-swift">struct TiltParallax<Content: View>: View {
    @StateObject private var motion = MotionStore()
    let depth: CGFloat
    let content: Content

    init(depth: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.depth = depth
        self.content = content()
    }

    var body: some View {
        content
            .rotation3DEffect(
                .radians(motion.pitch * 0.35),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .radians(-motion.roll * 0.35),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .offset(
                x: CGFloat(motion.roll) * depth,
                y: -CGFloat(motion.pitch) * depth
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: motion.roll)
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
    }
}
</code></pre>

<p>关键点：roll/pitch 已经被 CoreMotion 限制在 ±π，但用户实际持机区间一般在 ±0.3 rad，乘 0.35 后视差幅度 ~6°，舒适。<code>interactiveSpring</code> 把传感器毛刺打平，比直接绑定漂亮得多。</p>

<h3>5.10 重力感应小球 + 360 全景</h3>

<pre><code class="language-swift">// 重力球：直接用 gravity 投影
let g = motion.gravity
ball.velocity.x += CGFloat(g.x) * 0.6
ball.velocity.y += CGFloat(-g.y) * 0.6  // SwiftUI y 朝下，重力 y 朝上需取反

// 360 全景：用 yaw 驱动横向偏移
let normalized = (motion.yaw + .pi) / (2 * .pi)   // 0..1
panoramaScrollOffset = normalized * panoramaWidth
</code></pre>

<h3>5.11 AirPods 头部追踪：CMHeadphoneMotionManager（iOS 14+）</h3>

<pre><code class="language-swift">import CoreMotion

@MainActor
final class HeadphoneMotion: ObservableObject {
    @Published var headYaw: Double = 0
    private let mgr = CMHeadphoneMotionManager()

    func start() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let m else { return }
            self?.headYaw = m.attitude.yaw
        }
    }
}
</code></pre>

<p>iOS 18 起 <code>CMHeadphoneMotionManager</code> 在 Spatial Audio + AirPods Pro/Max/4 上可用，配合 <code>AVAudioEngine</code> 的 <code>renderingAlgorithm = .HRTFHQ</code> 实现头追沉浸声。注意 AirPods 的传感器与 iPhone 的是<strong>独立两个 manager</strong>，不会互相影响。</p>

<h3>5.12 CMPedometer 简介</h3>

<pre><code class="language-swift">import CoreMotion

let pedometer = CMPedometer()
if CMPedometer.isStepCountingAvailable() {
    pedometer.startUpdates(from: .now) { data, _ in
        guard let d = data else { return }
        print("步数:", d.numberOfSteps,
              "距离:", d.distance ?? 0,
              "配速:", d.currentPace ?? 0)
    }
}
</code></pre>

<p>需要 <code>NSMotionUsageDescription</code>。<code>queryPedometerData(from:to:)</code> 可以查历史 7 天（M 系列协处理器持久缓存）。</p>

<h3>5.13 Haptics 全景：三条路</h3>

<table>
<thead><tr><th>层级</th><th>API</th><th>iOS</th><th>定位</th></tr></thead>
<tbody>
<tr><td>声明式（首选）</td><td><code>.sensoryFeedback()</code></td><td>17+</td><td>SwiftUI 状态变化触发</td></tr>
<tr><td>命令式简易</td><td><code>UIImpactFeedbackGenerator</code> 等</td><td>10+</td><td>UIKit/老代码</td></tr>
<tr><td>编程式自定义</td><td><code>CHHapticEngine</code></td><td>13+（A12+）</td><td>自定义波形/AHAP/音画同步</td></tr>
</tbody>
</table>

<p>参考 WWDC 2019 #520 <em>Introducing Core Haptics</em>、WWDC 2023 #10257 <em>Bring rich haptic feedback to your app</em>。</p>

<h3>5.14 .sensoryFeedback() 全部 case（iOS 17+）</h3>

<ul>
<li><strong>语义类</strong>：<code>.success</code> / <code>.warning</code> / <code>.error</code>——对应通知反馈三档</li>
<li><strong>选择/导航</strong>：<code>.selection</code>——picker 翻档、tab 切换</li>
<li><strong>冲击</strong>：<code>.impact(weight:.light/.medium/.heavy, intensity: 0–1)</code>，iOS 17.5+ 加 <code>flexibility:.solid/.soft/.rigid</code></li>
<li><strong>数值变化</strong>：<code>.increase</code> / <code>.decrease</code>——slider 加减</li>
<li><strong>level</strong>：<code>.levelChange</code>——音量条之类离散等级</li>
<li><strong>过程</strong>：<code>.start</code> / <code>.stop</code>——录音/计时器开始结束</li>
<li><strong>对齐</strong>：<code>.alignment</code>——拖拽对齐到 grid/snap point</li>
<li><strong>轨迹</strong>：<code>.pathComplete</code>（iOS 17+ 部分版本）——完成手势路径</li>
</ul>

<h3>5.15 .sensoryFeedback trigger 三种写法</h3>

<pre><code class="language-swift">// 1. 任何变化都触发
.sensoryFeedback(.selection, trigger: pickerIndex)

// 2. 闭包按 old/new 决定要不要触发，并选择 case
.sensoryFeedback(trigger: scrollOffset) { old, new in
    let snap: CGFloat = 60
    return Int(old / snap) != Int(new / snap) ? .alignment : nil
}

// 3. 条件式：返回 Bool 决定固定 case 是否触发
.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7),
                 trigger: dragLocation) { old, new in
    abs(new.x - old.x) > 80
}
</code></pre>

<p>trigger 闭包内不要做重活——它在 main actor，频繁触发会卡渲染。</p>

<h3>5.16 CoreHaptics 核心模型</h3>

<ul>
<li><code>CHHapticEngine</code>：单 app 推荐复用一个实例。<code>start()</code> / <code>stop()</code>，监听 <code>resetHandler</code> / <code>stoppedHandler</code> 应对 audio session 中断、内存压力时引擎被 kill。</li>
<li><code>CHHapticPattern</code>：一组 <code>CHHapticEvent</code> + <code>CHHapticParameterCurve</code>。</li>
<li><code>CHHapticEvent</code>：
  <ul>
    <li><code>.hapticTransient</code>——单击型（≤几十 ms）</li>
    <li><code>.hapticContinuous</code>——持续型，需 <code>duration</code></li>
    <li>音频同步：<code>.audioContinuous</code> / <code>.audioCustom</code></li>
  </ul>
</li>
<li>关键 <code>CHHapticEventParameter</code>：<code>.hapticIntensity</code>（0–1 强度）、<code>.hapticSharpness</code>（0–1，越高越"脆"，类比"high pass"）、<code>.attackTime</code> / <code>.decayTime</code> / <code>.releaseTime</code>、<code>.sustained</code>。</li>
<li><code>CHHapticDynamicParameter</code> + <code>CHHapticParameterCurve</code>：在 pattern 播放过程中插值改变 intensity/sharpness。</li>
</ul>

<h3>5.17 CHHapticEngine 引擎封装（iOS 13+）</h3>

<pre><code class="language-swift">import CoreHaptics

@MainActor
final class HapticsEngine {
    static let shared = HapticsEngine()
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func prepare() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true

            e.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            e.stoppedHandler = { reason in
                print("Haptic engine stopped:", reason.rawValue)
            }
            try e.start()
            engine = e
        } catch {
            print("Haptic engine error:", error)
        }
    }

    func play(_ pattern: CHHapticPattern) {
        guard let engine else { return }
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic play error:", error)
        }
    }
}
</code></pre>

<h3>5.18 完整自定义 Pattern：充电式 ramp（"长按蓄力"）</h3>

<pre><code class="language-swift">func chargeUpPattern(duration: TimeInterval = 1.2) throws -> CHHapticPattern {
    let intensityCurve = CHHapticParameterCurve(
        parameterID: .hapticIntensityControl,
        controlPoints: [
            .init(relativeTime: 0,        value: 0.2),
            .init(relativeTime: duration * 0.5, value: 0.6),
            .init(relativeTime: duration,  value: 1.0)
        ],
        relativeTime: 0
    )
    let sharpnessCurve = CHHapticParameterCurve(
        parameterID: .hapticSharpnessControl,
        controlPoints: [
            .init(relativeTime: 0,        value: 0.1),
            .init(relativeTime: duration,  value: 0.9)
        ],
        relativeTime: 0
    )
    let continuous = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        ],
        relativeTime: 0,
        duration: duration
    )
    let click = CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        ],
        relativeTime: duration
    )
    return try CHHapticPattern(
        events: [continuous, click],
        parameterCurves: [intensityCurve, sharpnessCurve]
    )
}

HapticsEngine.shared.prepare()
if let p = try? chargeUpPattern() { HapticsEngine.shared.play(p) }
</code></pre>

<h3>5.19 AHAP JSON 加载</h3>

<p>AHAP（Apple Haptic and Audio Pattern）是 JSON 描述，方便设计师/音效人员独立产出。示例 <code>tap.ahap</code>：</p>

<pre><code class="language-swift">// {
//   "Version": 1,
//   "Pattern": [
//     { "Event": { "Time": 0, "EventType":"HapticTransient",
//       "EventParameters": [
//         {"ParameterID":"HapticIntensity","ParameterValue":0.9},
//         {"ParameterID":"HapticSharpness","ParameterValue":0.6}
//       ] } }
//   ]
// }

func playAHAP(named name: String) throws {
    guard let url = Bundle.main.url(forResource: name, withExtension: "ahap") else { return }
    try HapticsEngine.shared.engine?.playPattern(from: url)
}
</code></pre>

<p>AHAP 还可以同时声明 <code>AudioCustom</code> 事件，引用 bundle 内 wav，把震动与音频<strong>采样级同步</strong>——这是 Taptic Engine 区别于一般马达的关键能力。</p>

<h3>5.20 与音频同步：CHHapticEngine 同步播放</h3>

<pre><code class="language-swift">let resID = try engine.registerAudioResource(
    Bundle.main.url(forResource: "click", withExtension: "wav")!
)
let audio = CHHapticEvent(audioResourceID: resID, parameters: [], relativeTime: 0)
let haptic = CHHapticEvent(eventType: .hapticTransient,
                           parameters: [], relativeTime: 0)
let pattern = try CHHapticPattern(events: [audio, haptic], parameters: [])
try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
</code></pre>

<h3>5.21 UIKit 路线（仍受支持）</h3>

<pre><code class="language-swift">let n = UINotificationFeedbackGenerator()
n.prepare()
n.notificationOccurred(.success)

let s = UISelectionFeedbackGenerator()
s.prepare()
s.selectionChanged()

let i = UIImpactFeedbackGenerator(style: .medium)
i.prepare()
i.impactOccurred(intensity: 0.6)
</code></pre>

<p><code>prepare()</code> 提前唤醒 Taptic Engine，把延迟从 ~150ms 压到 ~10ms，长按场景务必调用。</p>

<h3>5.22 实战：播放器 scrubber 轻触觉 + 对齐震动</h3>

<pre><code class="language-swift">struct ScrubSlider: View {
    @State private var progress: Double = 0
    @State private var lastTickBucket: Int = 0
    var body: some View {
        GeometryReader { geo in
            Capsule().fill(.tertiary)
                .overlay(alignment: .leading) {
                    Capsule().fill(.tint)
                        .frame(width: geo.size.width * progress)
                }
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { v in
                        progress = min(max(0, v.location.x / geo.size.width), 1)
                    }
                )
        }
        .frame(height: 6)
        .sensoryFeedback(trigger: progress) { old, new in
            let bucket = Int(new * 30)
            return bucket != Int(old * 30) ? .selection : nil
        }
        .sensoryFeedback(.alignment, trigger: progress) { _, new in
            [0.0, 0.5, 1.0].contains { abs($0 - new) < 0.005 }
        }
    }
}
</code></pre>

<h3>5.23 实战：拖卡片对齐到 snap 点（结合 CoreMotion 的 gravity 偏置）</h3>

<pre><code class="language-swift">struct SnappingCard: View {
    @StateObject private var motion = MotionStore()
    @State private var offset: CGSize = .zero
    let snaps: [CGFloat] = [-120, 0, 120]

    var body: some View {
        RoundedRectangle(cornerRadius: 24).fill(.regularMaterial)
            .frame(width: 220, height: 320)
            .offset(x: offset.width + CGFloat(motion.gravity.x) * 6, y: offset.height)
            .gesture(
                DragGesture()
                    .onChanged { offset = $0.translation }
                    .onEnded { _ in
                        let nearest = snaps.min(by: { abs($0 - offset.width) < abs($1 - offset.width) }) ?? 0
                        withAnimation(.spring) { offset = CGSize(width: nearest, height: 0) }
                    }
            )
            .sensoryFeedback(.alignment, trigger: offset.width) { _, new in
                snaps.contains { abs($0 - new) < 2 }
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5),
                             trigger: offset == .zero)
            .onAppear { motion.start() }
    }
}
</code></pre>

<blockquote class="warning">
<p><strong>踩坑速查 / Pitfalls</strong></p>
<ul>
<li><strong>权限</strong>：<code>NSMotionUsageDescription</code> 必填，否则 iOS 14+ 直接 crash；CoreHaptics 不需要权限但需检查 <code>capabilitiesForHardware().supportsHaptics</code>（iPad、iPhone 7 之前不支持）。</li>
<li><strong>单例</strong>：<code>CMMotionManager</code> 整个 app 只允许一个；<code>CHHapticEngine</code> 也建议单例复用，避免 audio session 抢占。</li>
<li><strong>main actor</strong>：<code>startDeviceMotionUpdates(to:)</code> 的 handler 跑在你给的 queue 上，<strong>禁止</strong>直接修改 <code>@Published</code>——必须 <code>Task { @MainActor in ... }</code> 或 <code>OperationQueue.main</code>，否则编译警告 + 数据竞争。</li>
<li><strong>引擎被 reset</strong>：来电、Siri、长时间 idle 都会触发 <code>resetHandler</code>，必须在里面 <code>try engine.start()</code>，否则之后所有 play 静默失败。</li>
<li><strong>电量</strong>：deviceMotion 60Hz ≈ 1–2% CPU，120Hz 翻倍；离开页面务必 <code>stop()</code>，<code>onDisappear</code> 不够（sheet 盖住不会触发），用 <code>scenePhase</code> 双保险。</li>
<li><strong>低电量模式</strong>：用户开 Low Power Mode 时 Taptic Engine 仍工作但部分高频 sharpness 会被压缩，自定义 pattern 设计要在 0.4–0.8 sharpness 区间为主。</li>
<li><strong>静音开关</strong>：CoreHaptics 默认<strong>不</strong>受静音开关影响（与 UIKit generator 一致）；但如果 pattern 里包含 <code>audioCustom</code>，audio 部分会被静音，单独震动正常——这是常见错觉来源。</li>
<li><strong>simulator</strong>：simulator 不出震动也不出 deviceMotion 真实数据（可手动模拟），所有触觉/姿态调试必须真机。</li>
<li><strong>reference frame 漂移</strong>：<code>xArbitraryZVertical</code> 长时间运行 yaw 会缓慢漂；改用 <code>xArbitraryCorrectedZVertical</code>（要磁力计可用）。</li>
<li><strong>.sensoryFeedback 节流</strong>：trigger 每帧变化（如手势）时，闭包返回 <code>nil</code> 才能不触发；返回非 nil 但内容相同也会震，自己用 bucket/阈值过滤。</li>
<li><strong>AirPods Motion</strong>：<code>CMHeadphoneMotionManager</code> 与机身 manager 互不影响，但<strong>同一时间只允许一个 app 接收</strong>，被 FaceTime/电话占用时 <code>isDeviceMotionActive</code> 仍 true 但 handler 不再触发。</li>
</ul>
</blockquote>