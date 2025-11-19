@IsTest(SeeAllData=false)
private class UserProfileServiceTest {

    @IsTest
    static void testAdminDetection() {
        // Profil admin (FR ou EN)
        Profile adminProfile = [
            SELECT Id, Name
            FROM Profile
            WHERE Name IN ('System Administrator', 'Administrateur système')
            LIMIT 1
        ];

        // Utilisateur de test avec ce profil
        User adminUser = new User(
            LastName          = 'Admin User',
            Alias             = 'admtest',
            Email             = 'adm' + System.currentTimeMillis() + '@test.com',
            Username          = 'adm.' + System.currentTimeMillis() + '@test.com',
            CommunityNickname = 'adm' + System.currentTimeMillis(),
            TimeZoneSidKey    = 'Europe/Paris',
            LocaleSidKey      = 'fr_FR',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId         = adminProfile.Id
        );
        insert adminUser;

        System.runAs(adminUser) {
            UserProfileService.ProfileInfo info = UserProfileService.getCurrentProfileInfo();

            // On ne teste plus la chaîne exacte, seulement les flags
            System.assertEquals(
                true,
                info.isSystemAdmin,
                'L’admin doit être détecté comme System Admin'
            );
            System.assertEquals(
                false,
                info.isCommercial,
                'Un admin ne doit pas être détecté comme Commercial'
            );
        }
    }

    @IsTest
    static void testCommercialDetection() {
        // Profil standard (FR ou EN)
        Profile standardProfile = [
            SELECT Id, Name
            FROM Profile
            WHERE Name IN ('Standard User', 'Utilisateur standard')
            LIMIT 1
        ];

        // Utilisateur de test avec ce profil
        User commercialUser = new User(
            LastName          = 'Standard User',
            Alias             = 'stdtest',
            Email             = 'std' + System.currentTimeMillis() + '@test.com',
            Username          = 'std.' + System.currentTimeMillis() + '@test.com',
            CommunityNickname = 'std' + System.currentTimeMillis(),
            TimeZoneSidKey    = 'Europe/Paris',
            LocaleSidKey      = 'fr_FR',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId         = standardProfile.Id
        );
        insert commercialUser;

        System.runAs(commercialUser) {
            UserProfileService.ProfileInfo info = UserProfileService.getCurrentProfileInfo();

            System.assertEquals(
                false,
                info.isSystemAdmin,
                'Un standard user ne doit PAS être détecté comme admin'
            );
            System.assertEquals(
                true,
                info.isCommercial,
                'Le profil standard doit être détecté comme Commercial'
            );
        }
    }
}