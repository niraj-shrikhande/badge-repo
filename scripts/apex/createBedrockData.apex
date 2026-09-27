// ── Parent: Bedrock Enterprises (US HQ) ──────────────────────────────────────
Account bedrockHQ = new Account(
    Name = 'Bedrock Enterprises',
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+1 (415) 555-0100',
    Website = 'https://www.bedrockenterprises.com',
    BillingStreet = 'The Landmark @ One Market, Suite 300',
    BillingCity = 'San Francisco',
    BillingState = 'CA',
    BillingPostalCode = '94105',
    BillingCountry = 'United States',
    NumberOfEmployees = 12000,
    AnnualRevenue = 850000000,
    Description = 'Bedrock Enterprises is a global technology leader headquartered in San Francisco.'
);
insert bedrockHQ;

// ── Europe ───────────────────────────────────────────────────────────────────
Account bedrockEurope = new Account(
    Name = 'Bedrock Enterprises Europe',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+44 20 7946 0100',
    Website = 'https://eu.bedrockenterprises.com',
    BillingStreet = '30 St Mary Axe',
    BillingCity = 'London',
    BillingState = 'England',
    BillingPostalCode = 'EC3A 8EP',
    BillingCountry = 'United Kingdom',
    NumberOfEmployees = 2800,
    AnnualRevenue = 195000000,
    Description = 'European regional headquarters for Bedrock Enterprises, covering EMEA operations.'
);

Account bedrockGermany = new Account(
    Name = 'Bedrock Enterprises GmbH',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+49 89 2000 4100',
    Website = 'https://de.bedrockenterprises.com',
    BillingStreet = 'Maximilianstraße 35',
    BillingCity = 'Munich',
    BillingState = 'Bavaria',
    BillingPostalCode = '80539',
    BillingCountry = 'Germany',
    NumberOfEmployees = 1400,
    AnnualRevenue = 95000000,
    Description = 'German subsidiary serving DACH markets.'
);

Account bedrockFrance = new Account(
    Name = 'Bedrock Enterprises France SAS',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+33 1 4000 5100',
    Website = 'https://fr.bedrockenterprises.com',
    BillingStreet = '8 Avenue de l\'Opéra',
    BillingCity = 'Paris',
    BillingPostalCode = '75001',
    BillingCountry = 'France',
    NumberOfEmployees = 950,
    AnnualRevenue = 72000000,
    Description = 'French subsidiary focused on southern Europe expansion.'
);

// ── Middle East ───────────────────────────────────────────────────────────────
Account bedrockUAE = new Account(
    Name = 'Bedrock Enterprises Middle East',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+971 4 555 0200',
    Website = 'https://me.bedrockenterprises.com',
    BillingStreet = 'Level 15, DIFC Gate Building',
    BillingCity = 'Dubai',
    BillingPostalCode = '506621',
    BillingCountry = 'United Arab Emirates',
    NumberOfEmployees = 680,
    AnnualRevenue = 58000000,
    Description = 'Middle East regional HQ serving Gulf Cooperation Council markets.'
);

Account bedrockSaudi = new Account(
    Name = 'Bedrock Enterprises Saudi Arabia',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+966 11 555 0300',
    Website = 'https://sa.bedrockenterprises.com',
    BillingStreet = 'King Fahd Road, Al Olaya District',
    BillingCity = 'Riyadh',
    BillingPostalCode = '12211',
    BillingCountry = 'Saudi Arabia',
    NumberOfEmployees = 420,
    AnnualRevenue = 34000000,
    Description = 'Saudi subsidiary supporting Vision 2030 technology initiatives.'
);

// ── Asia ─────────────────────────────────────────────────────────────────────
Account bedrockAsia = new Account(
    Name = 'Bedrock Enterprises Asia Pacific',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+65 6555 0400',
    Website = 'https://apac.bedrockenterprises.com',
    BillingStreet = '1 Raffles Place, #20-01',
    BillingCity = 'Singapore',
    BillingPostalCode = '048616',
    BillingCountry = 'Singapore',
    NumberOfEmployees = 1600,
    AnnualRevenue = 120000000,
    Description = 'Asia Pacific regional headquarters for Bedrock Enterprises.'
);

Account bedrockJapan = new Account(
    Name = 'Bedrock Enterprises Japan KK',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+81 3 5555 0500',
    Website = 'https://jp.bedrockenterprises.com',
    BillingStreet = '2-1 Marunouchi, Chiyoda-ku',
    BillingCity = 'Tokyo',
    BillingPostalCode = '100-0005',
    BillingCountry = 'Japan',
    NumberOfEmployees = 1100,
    AnnualRevenue = 88000000,
    Description = 'Japanese subsidiary and largest APAC market by revenue.'
);

Account bedrockIndia = new Account(
    Name = 'Bedrock Enterprises India Pvt Ltd',
    ParentId = bedrockHQ.Id,
    Type = 'Customer',
    Industry = 'Technology',
    Phone = '+91 80 4555 0600',
    Website = 'https://in.bedrockenterprises.com',
    BillingStreet = 'Embassy Golf Links Business Park',
    BillingCity = 'Bengaluru',
    BillingState = 'Karnataka',
    BillingPostalCode = '560071',
    BillingCountry = 'India',
    NumberOfEmployees = 3200,
    AnnualRevenue = 65000000,
    Description = 'India engineering and delivery center, largest headcount outside the US.'
);

insert new List<Account>{ bedrockEurope, bedrockGermany, bedrockFrance, bedrockUAE, bedrockSaudi, bedrockAsia, bedrockJapan, bedrockIndia };

// ── Primary Contacts ──────────────────────────────────────────────────────────
insert new List<Contact>{
    new Contact(FirstName='Frederick', LastName='Stone', Title='Chief Executive Officer', Email='f.stone@bedrockenterprises.com', Phone='+1 (415) 555-0101', AccountId=bedrockHQ.Id),
    new Contact(FirstName='Eleanor', LastName='Hartley', Title='VP Europe', Email='e.hartley@bedrockenterprises.com', Phone='+44 20 7946 0101', AccountId=bedrockEurope.Id),
    new Contact(FirstName='Klaus', LastName='Weber', Title='Managing Director', Email='k.weber@bedrockenterprises.com', Phone='+49 89 2000 4101', AccountId=bedrockGermany.Id),
    new Contact(FirstName='Sophie', LastName='Dupont', Title='Country Manager', Email='s.dupont@bedrockenterprises.com', Phone='+33 1 4000 5101', AccountId=bedrockFrance.Id),
    new Contact(FirstName='Omar', LastName='Al-Rashid', Title='Regional Director ME', Email='o.alrashid@bedrockenterprises.com', Phone='+971 4 555 0201', AccountId=bedrockUAE.Id),
    new Contact(FirstName='Fatima', LastName='Al-Saud', Title='Country Head KSA', Email='f.alsaud@bedrockenterprises.com', Phone='+966 11 555 0301', AccountId=bedrockSaudi.Id),
    new Contact(FirstName='Mei', LastName='Tanaka', Title='VP Asia Pacific', Email='m.tanaka@bedrockenterprises.com', Phone='+65 6555 0401', AccountId=bedrockAsia.Id),
    new Contact(FirstName='Hiroshi', LastName='Yamamoto', Title='Country Manager Japan', Email='h.yamamoto@bedrockenterprises.com', Phone='+81 3 5555 0501', AccountId=bedrockJapan.Id),
    new Contact(FirstName='Priya', LastName='Sharma', Title='Engineering Director', Email='p.sharma@bedrockenterprises.com', Phone='+91 80 4555 0601', AccountId=bedrockIndia.Id)
};

// ── Opportunities ─────────────────────────────────────────────────────────────
insert new List<Opportunity>{
    new Opportunity(Name='Bedrock HQ — Platform Renewal', AccountId=bedrockHQ.Id, StageName='Proposal/Price Quote', CloseDate=Date.today().addDays(45), Amount=1200000, Probability=65),
    new Opportunity(Name='Bedrock Europe — Cloud Expansion', AccountId=bedrockEurope.Id, StageName='Value Proposition', CloseDate=Date.today().addDays(60), Amount=480000, Probability=50),
    new Opportunity(Name='Bedrock Germany — Data Services', AccountId=bedrockGermany.Id, StageName='Id. Decision Makers', CloseDate=Date.today().addDays(90), Amount=275000, Probability=40),
    new Opportunity(Name='Bedrock France — Support Package', AccountId=bedrockFrance.Id, StageName='Perception Analysis', CloseDate=Date.today().addDays(30), Amount=155000, Probability=70),
    new Opportunity(Name='Bedrock UAE — Digital Transformation', AccountId=bedrockUAE.Id, StageName='Proposal/Price Quote', CloseDate=Date.today().addDays(75), Amount=620000, Probability=55),
    new Opportunity(Name='Bedrock APAC — Integration Suite', AccountId=bedrockAsia.Id, StageName='Value Proposition', CloseDate=Date.today().addDays(50), Amount=390000, Probability=60),
    new Opportunity(Name='Bedrock Japan — AI Analytics', AccountId=bedrockJapan.Id, StageName='Proposal/Price Quote', CloseDate=Date.today().addDays(40), Amount=510000, Probability=72),
    new Opportunity(Name='Bedrock India — Dev Tools License', AccountId=bedrockIndia.Id, StageName='Needs Analysis', CloseDate=Date.today().addDays(120), Amount=180000, Probability=35)
};

System.debug('✅ Bedrock global account hierarchy created successfully.');
System.debug('Parent: Bedrock Enterprises (US HQ)');
System.debug('Children: Europe (UK, Germany, France), Middle East (UAE, Saudi), Asia (Singapore, Japan, India)');
