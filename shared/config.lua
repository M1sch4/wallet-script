local WalletConfig = {
    LicenseTypes = {
        { name = "driver", label = "Führerschein" },
        { name = "weapon", label = "Waffenschein" },
        { name = "fishing", label = "Angelschein" },
        { name = "hunting", label = "Jagdschein" },
        { name = "business", label = "Gewerbeschein" },
        { name = "pilot", label = "Pilotenlizenz" },
        { name = "boat", label = "Bootsführerschein" },
        { name = "vehiclekey", label = "Fahrzeugschlüssel", transferable = true }
    }
}

return WalletConfig 