import SwiftUI

struct MakeInRowSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay

    private var rowGoal: Int { block.consecutiveRequired ?? 5 }

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            day: day,
            stripConfig: .makeInRow(
                totalPutts: session.totalPutts,
                puttsTaken: session.currentPutt,
                consecutive: session.consecutiveSuccesses,
                goal: rowGoal
            ),
            headerIcon: .rec
        )
    }
}
