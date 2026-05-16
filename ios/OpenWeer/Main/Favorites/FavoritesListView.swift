import SwiftUI

/// Manage saved locations for rain push notifications.
///
/// Empty state guides the user into the existing location search; the
/// `LocationBar` flow is reused so we don't fork the search experience.
struct FavoritesListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = FavoritesStore.shared
    @State private var editingFavorite: Favorite?
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if store.favorites.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.owSurface.ignoresSafeArea())
            .navigationTitle("Favorieten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Klaar") { dismiss() }
                        .foregroundStyle(Color.owAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!store.canAdd)
                    .accessibilityIdentifier("favorites.add")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddFavoriteFromSearch { newFavorite in
                    store.add(newFavorite)
                    FavoritesSync.shared.schedule()
                    showingAddSheet = false
                }
            }
            .sheet(item: $editingFavorite) { fav in
                FavoriteEditView(favorite: fav) { updated in
                    store.update(updated)
                    FavoritesSync.shared.schedule()
                    editingFavorite = nil
                } onCancel: {
                    editingFavorite = nil
                }
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "star.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.owInkSecondary)
            Text("Nog geen favorieten")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.owInkPrimary)
            Text("Voeg een plek toe om een melding te krijgen voordat het daar gaat regenen.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.owInkSecondary)
                .padding(.horizontal, 40)
            Button {
                showingAddSheet = true
            } label: {
                Label("Plek toevoegen", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.owAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 12)
            .accessibilityIdentifier("favorites.empty.add")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        List {
            Section {
                ForEach(store.favorites) { fav in
                    Button {
                        editingFavorite = fav
                    } label: {
                        FavoriteRow(favorite: fav)
                    }
                    .listRowBackground(Color.owSurfaceCard)
                }
                .onDelete { offsets in
                    for idx in offsets {
                        store.remove(id: store.favorites[idx].id)
                    }
                    FavoritesSync.shared.schedule()
                }
                .onMove { from, to in
                    store.move(fromOffsets: from, toOffset: to)
                    FavoritesSync.shared.schedule()
                }
            } footer: {
                Text("Maximaal \(FavoritesStore.maxCount) favorieten per apparaat.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.owInkSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.owSurface)
        .environment(\.editMode, .constant(.active))
    }
}

private struct FavoriteRow: View {
    let favorite: Favorite

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.owAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.owInkSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let lead = favorite.alertPrefs.leadTime.minutes
        let intensityLabel: String = {
            switch favorite.alertPrefs.threshold {
            case .light:    return "lichte regen"
            case .moderate: return "matige regen"
            case .heavy:    return "zware regen"
            }
        }()
        return "\(intensityLabel) · \(lead) min vooraf"
    }
}
