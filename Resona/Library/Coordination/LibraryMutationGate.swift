import Foundation

nonisolated struct LibraryMutationReservation: Equatable, Sendable {
    fileprivate let id: UUID
}

nonisolated enum LibraryMutationAcquisition: Equatable, Sendable {
    case acquired(LibraryMutationReservation)
    case busy
}

actor LibraryMutationGate {
    private var activeReservation: LibraryMutationReservation?

    func acquire() -> LibraryMutationAcquisition {
        guard activeReservation == nil else {
            return .busy
        }

        let reservation = LibraryMutationReservation(id: UUID())
        activeReservation = reservation
        return .acquired(reservation)
    }

    func release(_ reservation: LibraryMutationReservation) {
        guard activeReservation == reservation else {
            return
        }
        activeReservation = nil
    }

    func isHeld(_ reservation: LibraryMutationReservation) -> Bool {
        activeReservation == reservation
    }
}
