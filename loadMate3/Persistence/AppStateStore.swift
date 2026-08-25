import Foundation
import SwiftData

enum AppStateStore {
  /// Prefer the canonical singleton record when multiple `AppState` rows exist (e.g. after iCloud merge).
  static func canonical(from states: [AppState]) -> AppState? {
    states.first { $0.id == LoadMateSyncIDs.appState } ?? states.first
  }

  /// Ensures exactly one canonical `AppState` exists and merges duplicates from older installs.
  @MainActor
  static func resolve(in context: ModelContext, existing: [AppState] = []) -> AppState {
    let allStates = existing.isEmpty
      ? ((try? context.fetch(FetchDescriptor<AppState>())) ?? [])
      : existing

    if let canonical = allStates.first(where: { $0.id == LoadMateSyncIDs.appState }) {
      SyncDebugSeedLog.record("[seed] AppState already exists; skipped create")
      mergeDuplicates(into: canonical, from: allStates, in: context)
      return canonical
    }

    if allStates.count == 1, let lone = allStates.first {
      SyncDebugSeedLog.record("[seed] AppState already exists (legacy id); skipped create")
      lone.id = LoadMateSyncIDs.appState
      save(context)
      return lone
    }

    if allStates.count > 1 {
      SyncDebugSeedLog.record("[seed] AppState already exists (\(allStates.count) rows); merging instead of creating")
      return mergeAll(allStates, in: context)
    }

    SyncDebugSeedLog.record("[seed] Creating AppState")
    let state = AppState()
    context.insert(state)
    save(context)
    return state
  }

  @MainActor
  private static func mergeDuplicates(
    into canonical: AppState,
    from allStates: [AppState],
    in context: ModelContext
  ) {
    // Same stable id on every device — CloudKit can leave multiple rows with identical ids.
    let duplicates = allStates.filter { $0 !== canonical }
    guard !duplicates.isEmpty else { return }

    for duplicate in duplicates {
      mergeFields(from: duplicate, into: canonical)
      context.delete(duplicate)
    }
    save(context)
  }

  @MainActor
  private static func mergeAll(_ states: [AppState], in context: ModelContext) -> AppState {
    let canonical = AppState()
    context.insert(canonical)

    for state in states {
      mergeFields(from: state, into: canonical)
      context.delete(state)
    }

    canonical.id = LoadMateSyncIDs.appState
    save(context)
    return canonical
  }

  private static func mergeFields(from source: AppState, into target: AppState) {
    if source.disclaimerAccepted {
      target.disclaimerAccepted = true
      if let acceptedAt = source.acceptedAt {
        target.acceptedAt = max(target.acceptedAt ?? .distantPast, acceptedAt)
      }
    }

    if target.activeProfileID == nil {
      target.activeProfileID = source.activeProfileID
    }

    target.didSeedDefaultProfiles = target.didSeedDefaultProfiles || source.didSeedDefaultProfiles
    target.didSeedDefaultChecklist = target.didSeedDefaultChecklist || source.didSeedDefaultChecklist

    let sourceProbeDate = source.syncProbeUpdatedAt ?? .distantPast
    let targetProbeDate = target.syncProbeUpdatedAt ?? .distantPast
    if sourceProbeDate > targetProbeDate {
      target.syncProbeSequence = source.syncProbeSequence
      target.syncProbeValue = source.syncProbeValue
      target.syncProbeUpdatedAt = source.syncProbeUpdatedAt
      target.syncProbeUpdatedBy = source.syncProbeUpdatedBy
    }
  }

  private static func save(_ context: ModelContext) {
    _ = SyncDebugSaveHelper.save(context, source: "AppStateStore.save")
  }
}
