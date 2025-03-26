// The Swift Programming Language
// https://docs.swift.org/swift-book

/// Основной класс для работы с сервисами очистки устройства.
public class CleanerKit {
    
    /// Сервис для работы с контактами.
    public private(set) lazy var contactsService: ContactsService
    
    /// Сервис для поиска и удаления дубликатов.
    public private(set) lazy var dublicateService: DuplicateService
    
    /// Сервис для работы с запросами на доступ к фото.
    public private(set) lazy var photoRequestService: PhotoRequestService
    
    /// Сервис для получения информации о хранении данных.
    public private(set) lazy var storageUsageService: StorageUsageService
    
    /// Сервис для сжатия видео.
    public private(set) lazy var videoCompressionService: VideoCompressionService
    
    /// Инициализация всех сервисов.
    public init() {
        self.contactsService = ContactsService.shared
        self.dublicateService = DuplicateService.shared
        self.photoRequestService = PhotoRequestService.shared
        self.storageUsageService = StorageUsageService.shared
        self.videoCompressionService = VideoCompressionService.shared
    }
}
