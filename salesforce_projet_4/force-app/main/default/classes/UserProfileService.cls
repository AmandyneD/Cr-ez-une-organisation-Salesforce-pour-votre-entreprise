public with sharing class UserProfileService {

    public class ProfileInfo {
        @AuraEnabled public String  profileName   { get; set; }
        @AuraEnabled public Boolean isSystemAdmin { get; set; }
        @AuraEnabled public Boolean isCommercial  { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static ProfileInfo getCurrentProfileInfo() {
        User u = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        ProfileInfo info = new ProfileInfo();
        info.profileName = u.Profile.Name;

        info.isSystemAdmin = (
            u.Profile.Name == 'System Administrator' ||
            u.Profile.Name == 'Administrateur système'
        );

        info.isCommercial = (
            u.Profile.Name == 'Standard User' ||
            u.Profile.Name == 'Utilisateur standard'
        );

        return info;
    }
}