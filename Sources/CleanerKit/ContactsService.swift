//
//  ContactsService.swift
//  Cleaner
//
//  Created by Александр Назаров on 26.03.2025.
//

import Foundation
import Contacts

final class ContactsService {
    
    static let shared = ContactsService()
    private let contactStore = CNContactStore()
    
    private var fetchedContacts = [CNContact]()
    
    private init() {}
    
    /// Проверяет и запрашивает доступ к контактам
    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                contactStore.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Извлекает контакты (если разрешение получено)
    func fetchContacts() async -> [CNContact]? {
        guard await requestAccess() else { return nil }
        
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [CNContact] = []
        
        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            fetchedContacts = contacts
            return contacts
        } catch {
            print("Ошибка при загрузке контактов: \(error)")
            return nil
        }
    }
    
    func deleteContactFromDevice(identifier: String) -> Bool {
        guard let contact = fetchedContacts.first(where: { $0.identifier == identifier }) else { return false }
        guard let contactToDelete = contact.mutableCopy() as? CNMutableContact else { return false }
        
        let store = CNContactStore()
        
        let deleteRequest = CNSaveRequest()
        deleteRequest.delete(contactToDelete)
        
        do {
            try store.execute(deleteRequest)
            return true
        } catch {
            print("Ошибка при удалении контакта с устройства: \(error.localizedDescription)")
            return false
        }
    }
}
