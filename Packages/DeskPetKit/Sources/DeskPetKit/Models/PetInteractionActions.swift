import Foundation

/// Shared mutations used by App, Widget, and future watch shortcuts.
public enum PetInteractionActions {

    @discardableResult
    public static func feed(_ food: Food = .fish) -> PetState {
        PetStorage.updateCurrent { state in
            state.reconcile()
            let before = state
            let previousLevel = state.level
            state.apply(.userFed(food))
            guard state != before else { return }

            EventLogStore.append(PetEventLogEntry(
                petID: state.petID,
                kind: .fed,
                detail: "喂了 \(food.rawValue)"
            ))
            logLevelUpIfNeeded(previousLevel: previousLevel, state: state)
        }
    }

    @discardableResult
    public static func pet() -> PetState {
        PetStorage.updateCurrent { state in
            state.reconcile()
            let previousLevel = state.level
            state.apply(.userPetted)

            EventLogStore.append(PetEventLogEntry(
                petID: state.petID,
                kind: .petted,
                detail: "摸了摸头"
            ))
            logLevelUpIfNeeded(previousLevel: previousLevel, state: state)
        }
    }

    private static func logLevelUpIfNeeded(previousLevel: Int, state: PetState) {
        guard state.level > previousLevel else { return }
        EventLogStore.append(PetEventLogEntry(
            petID: state.petID,
            kind: .leveledUp,
            detail: "升到 Lv.\(state.level)"
        ))
    }
}
