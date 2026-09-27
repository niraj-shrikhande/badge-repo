public with sharing class ClientPlanPDFController {

    public Account account { get; private set; }
    public Contact primaryContact { get; private set; }
    public List<Opportunity> opportunities { get; private set; }
    public List<Entitlement> entitlements { get; private set; }
    public List<SubsidiaryRow> subsidiaryRows { get; private set; }
    public Decimal totalPipelineValue { get; private set; }
    public Integer growthMarketCount { get; private set; }
    public List<SubsidiaryRow> europeRows     { get; private set; }
    public List<SubsidiaryRow> middleEastRows { get; private set; }
    public List<SubsidiaryRow> asiaRows       { get; private set; }
    public List<MapPin> mapPins { get; private set; }

    public class SubsidiaryRow {
        public Account acct { get; set; }
        public Boolean isGrowthMarket { get; set; }
    }

    public class MapPin {
        public String cx      { get; set; }
        public String cy      { get; set; }
        public String tx      { get; set; }
        public String ty      { get; set; }
        public String fill    { get; set; }
        public Integer radius { get; set; }
        public String label   { get; set; }
    }

    private static final Set<String> GROWTH_MARKET_COUNTRIES = new Set<String>{
        'India', 'Saudi Arabia', 'United Arab Emirates', 'Japan', 'Singapore'
    };

    // Fixed city coordinates [lat, lng] — keyed by BillingCity
    private static final Map<String, Decimal[]> CITY_COORDS = new Map<String, Decimal[]>{
        'San Francisco' => new Decimal[]{ 37.8,  -122.4 },
        'London'        => new Decimal[]{ 51.5,  -0.1   },
        'Munich'        => new Decimal[]{ 48.1,   11.6  },
        'Paris'         => new Decimal[]{ 48.9,    2.4  },
        'Dubai'         => new Decimal[]{ 25.2,   55.3  },
        'Riyadh'        => new Decimal[]{ 24.7,   46.7  },
        'Singapore'     => new Decimal[]{ 1.4,   103.8  },
        'Tokyo'         => new Decimal[]{ 35.7,  139.7  },
        'Bengaluru'     => new Decimal[]{ 13.0,   77.6  }
    };

    private static String lngToX(Decimal lng) {
        return ((lng + 180) * (760.0 / 360.0)).setScale(1).toPlainString();
    }
    private static String latToY(Decimal lat) {
        return ((90 - lat) * (380.0 / 180.0)).setScale(1).toPlainString();
    }
    private static String lngToTx(Decimal lng) {
        return ((lng + 180) * (760.0 / 360.0) + 8).setScale(1).toPlainString();
    }
    private static String latToTy(Decimal lat) {
        return ((90 - lat) * (380.0 / 180.0) + 4).setScale(1).toPlainString();
    }

    public ClientPlanPDFController() {
        Id accountId = ApexPages.currentPage().getParameters().get('id');
        if (accountId == null) return;

        account = [
            SELECT Id, Name, Industry, Phone, Website, BillingStreet, BillingCity,
                   BillingState, BillingPostalCode, BillingCountry,
                   NumberOfEmployees, AnnualRevenue, Type, Owner.Name, Description
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Title, Email, Phone, MobilePhone
            FROM Contact
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        primaryContact = contacts.isEmpty() ? null : contacts[0];

        opportunities = [
            SELECT Id, Name, StageName, Amount, CloseDate, Probability, Owner.Name
            FROM Opportunity
            WHERE AccountId = :accountId
              AND IsClosed = false
            WITH USER_MODE
            ORDER BY CloseDate ASC
            LIMIT 50
        ];

        Decimal total = 0;
        for (Opportunity opp : opportunities) {
            if (opp.Amount != null) total += opp.Amount;
        }
        totalPipelineValue = total;

        entitlements = [
            SELECT Id, Name, Status, StartDate, EndDate, Asset.Name, Type
            FROM Entitlement
            WHERE AccountId = :accountId
              AND Status = 'Active'
            WITH USER_MODE
            ORDER BY EndDate ASC
            LIMIT 50
        ];

        List<Account> subsidiaries = [
            SELECT Id, Name, BillingCity, BillingCountry
            FROM Account
            WHERE ParentId = :accountId
              AND BillingCountry != null
            WITH USER_MODE
            ORDER BY BillingCountry ASC
        ];

        subsidiaryRows = new List<SubsidiaryRow>();
        growthMarketCount = 0;
        for (Account sub : subsidiaries) {
            SubsidiaryRow row = new SubsidiaryRow();
            row.acct = sub;
            row.isGrowthMarket = GROWTH_MARKET_COUNTRIES.contains(sub.BillingCountry);
            if (row.isGrowthMarket) growthMarketCount++;
            subsidiaryRows.add(row);
        }

        buildRegions();
        buildMapPins();
    }

    private void buildMapPins() {
        mapPins = new List<MapPin>();

        // HQ pin
        if (account.BillingCity != null && CITY_COORDS.containsKey(account.BillingCity)) {
            Decimal[] coords = CITY_COORDS.get(account.BillingCity);
            MapPin p = new MapPin();
            p.cx = lngToX(coords[1]); p.cy = latToY(coords[0]);
            p.tx = lngToTx(coords[1]); p.ty = latToTy(coords[0]);
            p.fill = '#032D60'; p.radius = 7; p.label = account.BillingCity + ' (HQ)';
            mapPins.add(p);
        }

        // Subsidiary pins
        for (SubsidiaryRow row : subsidiaryRows) {
            String city = row.acct.BillingCity;
            if (city != null && CITY_COORDS.containsKey(city)) {
                Decimal[] coords = CITY_COORDS.get(city);
                MapPin p = new MapPin();
                p.cx = lngToX(coords[1]); p.cy = latToY(coords[0]);
                p.tx = lngToTx(coords[1]); p.ty = latToTy(coords[0]);
                p.fill = row.isGrowthMarket ? '#2e7d32' : '#0176d3';
                p.radius = 5;
                p.label = city;
                mapPins.add(p);
            }
        }
    }

    private void buildRegions() {
        europeRows     = new List<SubsidiaryRow>();
        middleEastRows = new List<SubsidiaryRow>();
        asiaRows       = new List<SubsidiaryRow>();

        Set<String> europe     = new Set<String>{'United Kingdom','Germany','France','Spain','Italy','Netherlands','Sweden','Switzerland'};
        Set<String> middleEast = new Set<String>{'United Arab Emirates','Saudi Arabia','Qatar','Kuwait','Bahrain','Oman','Israel'};
        Set<String> asia       = new Set<String>{'India','Japan','Singapore','China','Australia','South Korea','Hong Kong','Malaysia','Indonesia'};

        for (SubsidiaryRow row : subsidiaryRows) {
            String c = row.acct.BillingCountry;
            if      (europe.contains(c))     europeRows.add(row);
            else if (middleEast.contains(c)) middleEastRows.add(row);
            else if (asia.contains(c))       asiaRows.add(row);
        }
    }

    public String getFormattedRevenue() {
        if (account == null || account.AnnualRevenue == null) return '-';
        return '$' + String.valueOf(account.AnnualRevenue.format());
    }

    public String getFormattedPipeline() {
        if (totalPipelineValue == null) return '$0';
        return '$' + String.valueOf(totalPipelineValue.format());
    }

    public String getBillingAddress() {
        if (account == null) return '';
        List<String> parts = new List<String>();
        if (account.BillingStreet != null) parts.add(account.BillingStreet);
        if (account.BillingCity != null) parts.add(account.BillingCity);
        if (account.BillingState != null) parts.add(account.BillingState);
        if (account.BillingPostalCode != null) parts.add(account.BillingPostalCode);
        if (account.BillingCountry != null) parts.add(account.BillingCountry);
        return String.join(parts, ', ');
    }
}
