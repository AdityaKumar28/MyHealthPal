import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        for _ in 0..<10 {
            let sample = Item(context: context)
            sample.timestamp = Date()
        }
        do {
            try context.save()
        } catch {
            // In a preview environment, don’t crash the app; just log the error.
            let nsError = error as NSError
            print("[PersistenceController.preview] Failed to save preview context: \(nsError), \(nsError.userInfo)")
        }
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyHealthPal")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Log the error instead of aborting; in a real app you might display an alert
                print("[PersistenceController] Failed to load persistent store: \(error), \(error.userInfo)")
            }
        }
        // Merge changes from other contexts automatically
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
