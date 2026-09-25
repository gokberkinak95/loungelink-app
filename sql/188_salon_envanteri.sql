-- ============================================================
-- 188 · SALON ENVANTERİ — THY resmî listelerinden tam kapsam
-- 17 Ağustos 2026
--
-- KAYNAK: turkishairlines.com yurtiçi / yurtdışı / anlaşmalı lounge
-- sayfalarının 42 ekran görüntüsü (12 Ağu 2026'da alındı), sheet
-- sheet ayrılmış hâliyle. Transkript: salon_envanteri.md · salonlar.csv
--
-- 🔴 NEDEN GEREKLİ: cihazda "lounge listeleri boş geliyor" ve
-- "kapsamımız bundan çok çok daha fazlası" bildirildi. Ölçüm doğruladı:
-- katalogda 22 havalimanı vardı, THY'nin kendi listesi 219 havalimanı
-- ve 255 salon içeriyor. Yani ürünün en görünür ekranı kaynağın
-- onda birini gösteriyordu.
--
-- 🔴 BU DOSYA ÜRETİLMİŞTİR (yeni/gen188.py). Elle düzenleme; kaynak
-- CSV'yi düzelt ve üreteci tekrar koş. Aksi hâlde bir sonraki
-- güncellemede bu düzenleme sessizce kaybolur.
--
-- MEVCUT VERİYE DOKUNMAZ: her ekleme `on conflict do nothing/update`
-- ile idempotenttir; hiçbir satır silinmez, pasife çekilmez.
-- ============================================================

set local statement_timeout = '600s';

-- ---- 1) HAVALİMANLARI ----
-- 🔴 airports.code char(3); venue eklemeden ONCE havalimani var olmali,
-- yoksa FK patlar. 107'nin dersi: `where exists (select 1 from airports)`
-- ile sessizce atlanan satirlar ALTI TUR fark edilmedi.
insert into airports (code, name, city, country) values
  ('ABJ', 'Felix Houphouet Boigny Uluslararası Havalimanı', 'Abidjan', 'Fildişi Sahili'),
  ('ABV', 'Nnamdi Azikiwe Havalimanı', 'Abuja', 'Nijerya'),
  ('ACC', 'Kotoka Uluslararası Havalimanı', 'Akra', 'Gana'),
  ('ADB', 'İzmir Adnan Menderes Havalimanı', 'İzmir', 'Türkiye'),
  ('ADD', 'Bole Uluslararası Havalimanı', 'Addis Ababa', 'Etiyopya'),
  ('AGP', 'Malaga-Costa Del Sol Havalimanı', 'Malaga', 'İspanya'),
  ('ALA', 'Almatı Uluslararası Havalimanı', 'Almatı', 'Kazakistan'),
  ('ALG', 'Houari Boumediene Havalimanı', 'Dar El Beida', 'Cezayir'),
  ('AMM', 'Kraliçe Aliye Uluslararası Havalimanı', 'Amman', 'Ürdün'),
  ('AMS', 'Amsterdam Schiphol Havalimanı', 'Amsterdam', 'Hollanda'),
  ('AQJ', 'Kral Hüseyin Uluslararası Havalimanı', 'Akabe', 'Ürdün'),
  ('ASR', 'Kayseri Havalimanı', 'Kayseri', 'Türkiye'),
  ('ATH', 'Atina Uluslararası Havalimanı', 'Atina', 'Yunanistan'),
  ('ATL', 'Hartsfield-Jackson Havalimanı', 'Atlanta', 'ABD'),
  ('AUH', 'Abu Dabi Uluslararası Havalimanı', 'Abu Dabi', 'Birleşik Arap Emirlikleri'),
  ('AYT', 'Antalya Havalimanı', 'Antalya', 'Türkiye'),
  ('BAH', 'Bahreyn Uluslararası Havalimanı', 'Muharrak', 'Bahreyn'),
  ('BCN', 'Barselona El Prat Havalimanı', 'Barselona', 'İspanya'),
  ('BEG', 'Nikola Tesla Havalimanı', 'Belgrad', 'Sırbistan'),
  ('BER', 'Brandenburg Havalimanı', 'Berlin', 'Almanya'),
  ('BEY', 'Refik Hariri Uluslararası Havalimanı', 'Beyrut', 'Lübnan'),
  ('BGW', 'Bağdat International Airport', 'Bağdat', 'Irak'),
  ('BHX', 'Birmingham Havalimanı', 'Birmingham', 'Birleşik Krallık (İngiltere)'),
  ('BIO', 'Bilbao Havalimanı', 'Bilbao', 'İspanya'),
  ('BJL', 'Banjul Uluslararası Havalimanı', 'Banjul', 'Gambiya'),
  ('BJV', 'Milas-Bodrum Havalimanı', 'Bodrum / Muğla', 'Türkiye'),
  ('BKK', 'Bangkok Suvarnabhumi Uluslararası Havalimanı', 'Bangkok', 'Tayland'),
  ('BKO', 'Modibo Keita Uluslararası Havalimanı', 'Bamako', 'Mali'),
  ('BLL', 'Billund Havalimanı', 'Billund', 'Danimarka'),
  ('BLQ', 'Guglielmo Marconi Havalimanı', 'Bolonya', 'İtalya'),
  ('BOD', 'Bordeaux-Mérignac Havalimanı', 'Bordo', 'Fransa'),
  ('BOG', 'El Dorado Uluslararası Havalimanı', 'Bogota', 'Kolombiya'),
  ('BOM', 'Chhatrapati Shivaji Uluslararası Havalimanı', 'Mumbai', 'Hindistan'),
  ('BOS', 'Logan Uluslararası Havalimanı', 'Boston', 'ABD'),
  ('BRE', 'Bremen Havalimanı', 'Bremen', 'Almanya'),
  ('BRI', 'Bari Havalimanı', 'Bari', 'İtalya'),
  ('BRU', 'Brüksel Havalimanı', 'Brüksel', 'Belçika'),
  ('BSL', 'Mulhouse Freiburg Havalimanı', 'Basel', 'İsviçre'),
  ('BSR', 'Basra Uluslararası Havalimanı', 'Basra', 'Irak'),
  ('BUD', 'Ferenc Liszt Uluslararası Havalimanı', 'Budapeşte', 'Macaristan'),
  ('BUS', 'Batum Uluslararası Havalimanı', 'Batum', 'Gürcistan'),
  ('CAI', 'Kahire Uluslararası Havalimanı', 'Kahire', 'Mısır'),
  ('CAN', 'Baiyun Uluslararası Havalimanı', 'Guanco (Guangzhou)', 'Çin'),
  ('CCS', 'Simon Bolivar Uluslararası Havalimanı', 'Karakas', 'Venezuela'),
  ('CDG', 'Charles de Gaulle Havalimanı', 'Paris', 'Fransa'),
  ('CEB', 'Mactan-Cebu Uluslararası Havalimanı', 'Cebu', 'Filipinler'),
  ('CGK', 'Soekarno-Hatta Uluslararası Havalimanı', 'Cakarta', 'Endonezya'),
  ('CGN', 'Bonn Havalimanı', 'Köln', 'Almanya'),
  ('CKY', 'Ahmed Sékou Touré Uluslararası Havalimanı', 'Konakri', 'Gine'),
  ('CLJ', 'Cluj Uluslararası Havaalanı', 'Cluj', 'Romanya'),
  ('CMB', 'Bandaranaike Uluslararası Havalimanı', 'Katunayake (Kolombo)', 'Sri Lanka'),
  ('CMN', 'Muhammed V Uluslararası Havalimanı', 'Kazablanka', 'Fas'),
  ('COO', 'Cotonou Havalimanı', 'Cotonou', 'Benin'),
  ('COV', 'Çukurova Uluslararası Havalimanı', 'Adana / Mersin', 'Türkiye'),
  ('CPH', 'Kopenhag Kastrup Havalimanı', 'Kopenhag', 'Danimarka'),
  ('CPT', 'Cape Town Uluslararası Havalimanı', 'Cape Town', 'Güney Afrika'),
  ('CTA', 'Katanya Fontanarossa Havalimanı', 'Katanya', 'İtalya'),
  ('CUN', 'Cancun Havalimanı', 'Cancun', 'Meksika'),
  ('DAC', 'Hazret Shahjalal Uluslararası Havalimanı', 'Dakka', 'Bangladeş'),
  ('DAR', 'Dar Es Salaam Uluslararası Havalimanı', 'Dar Es Selam', 'Tanzanya'),
  ('DBV', 'Dubrovnik Havalimanı', 'Dubrovnik', 'Hırvatistan'),
  ('DEL', 'Indira Gandhi Uluslararası Havalimanı', 'New Delhi', 'Hindistan'),
  ('DEN', 'Denver Uluslararası Havalimanı', 'Denver', 'ABD'),
  ('DFW', 'Dallas/Fort Worth Uluslararası Havalimanı', 'Dallas', 'ABD'),
  ('DLA', 'Douala Uluslararası Havalimanı', 'Douala', 'Kamerun'),
  ('DMM', 'Kral Fahd Uluslararası Havalimanı', 'Dammam', 'Suudi Arabistan'),
  ('DOH', 'Hamad Uluslararası Havalimanı', 'Doha', 'Katar'),
  ('DPS', 'Ngurah Rai Uluslararası Havalimanı', 'Denpasar', 'Endonezya'),
  ('DSS', 'Blaise Diagne Uluslararası Havalimanı', 'Dakar', 'Senegal'),
  ('DTW', 'Detroit Metropolitan Havalimanı', 'Detroit', 'ABD'),
  ('DUR', 'Kral Shaka Uluslararası Havalimanı', 'Durban', 'Güney Afrika'),
  ('DUS', 'Rhein Ruhr Uluslararası Havalimanı', 'Düsseldorf', 'Almanya'),
  ('DXB', 'Dubai Uluslararası Havalimanı', 'Dubai', 'Birleşik Arap Emirlikleri'),
  ('EBB', 'Entebbe Uluslararası Havalimanı', 'Entebbe', 'Uganda'),
  ('EBL', 'Erbil Havalimanı', 'Erbil', 'Irak'),
  ('ECN', 'Ercan Havalimanı', 'Lefkoşa', 'Kuzey Kıbrıs Türk Cumhuriyeti'),
  ('EDI', 'Edinburgh Uluslararası Havalimanı', 'Edinburgh', 'Birleşik Krallık (İskoçya)'),
  ('ESB', 'Ankara Esenboğa Havalimanı', 'Ankara', 'Türkiye'),
  ('EWR', 'Newark Liberty Uluslararası Havalimanı', 'Newark', 'ABD'),
  ('EZE', 'Ezeiza Uluslararası Havalimanı (EZE)', 'Buenos Aires', 'Arjantin'),
  ('FCO', 'Fiumicino - Leonardo Da Vinci Havalimanı', 'Roma', 'İtalya'),
  ('FIH', 'N''Djili Uluslararası Havalimanı', 'Kinşasa', 'Demokratik Kongo'),
  ('FNA', 'Lungi Uluslararası Havalimanı', 'Freetown', 'Sierra Leone'),
  ('FRA', 'Frankfurt Havalimanı', 'Frankfurt', 'Almanya'),
  ('FRU', 'Manas Uluslararası Havalimanı', 'Bişkek', 'Kırgızistan'),
  ('GOT', 'Landvetter Havalimanı', 'Göteborg', 'İsveç'),
  ('GRU', 'Guarulhos Havalimanı', 'Sao Paulo', 'Brezilya'),
  ('GVA', 'Cenevre Havalimanı', 'Cenevre', 'İsviçre'),
  ('GYD', 'Haydar Aliyev Uluslararası Havalimanı', 'Bakü', 'Azerbaycan'),
  ('GZT', 'Gaziantep Havalimanı', 'Gaziantep', 'Türkiye'),
  ('HAJ', 'Hannover Havalimanı', 'Hannover', 'Almanya'),
  ('HAM', 'Fhulsbuttel Havalimanı', 'Hamburg', 'Almanya'),
  ('HAN', 'Noi Bai Uluslararası Havalimanı', 'Hanoi', 'Vietnam'),
  ('HAV', 'Jose Marti Uluslararası Havalimanı', 'Havana', 'Küba'),
  ('HBE', 'Borg El Arab Havalimanı', 'İskenderiye', 'Mısır'),
  ('HEL', 'Helsinki-Vantaa Havalimanı', 'Helsinki', 'Finlandiya'),
  ('HKG', 'Hong Kong Uluslararası Havalimanı', 'Hong Kong', 'Hong Kong'),
  ('HKT', 'Puket Uluslararası Havalimanı', 'Puket', 'Tayland'),
  ('HND', 'Haneda Uluslararası Havalimanı', 'Tokyo', 'Japonya'),
  ('HRG', 'Hurgada Havalimanı', 'Hurgada', 'Mısır'),
  ('HTY', 'Hatay Havalimanı', 'Hatay', 'Türkiye'),
  ('IAD', 'Washington Dulles Uluslararası Havalimanı', 'Washington', 'ABD'),
  ('IAH', 'George Bush Kıtalararası Havalimanı', 'Houston', 'ABD'),
  ('ICN', 'Incheon Uluslararası Havalimanı', 'Incheon (Seul)', 'Güney Kore'),
  ('ISB', 'İslamabad Uluslararası Havalimanı', 'İslamabad', 'Pakistan'),
  ('IST', 'İstanbul Havalimanı', 'İstanbul', 'Türkiye'),
  ('JFK', 'John F. Kennedy Uluslararası Havalimanı', 'New York', 'ABD'),
  ('JIB', 'Ambouli Uluslararası Havalimanı', 'Ambouli (Cibuti)', 'Cibuti'),
  ('JNB', 'Johannesburg Havalimanı', 'Johannesburg', 'Güney Afrika'),
  ('JRO', 'Kilimanjaro Uluslararası Havalimanı', 'Kilimanjaro', 'Tanzanya'),
  ('KBL', 'Kabil Uluslararası Havalimanı', 'Kabil', 'Afganistan'),
  ('KGL', 'Kigali Havalimanı', 'Kigali', 'Ruanda'),
  ('KHI', 'Jinnah Uluslararası Havalimanı', 'Karaçi', 'Pakistan'),
  ('KIX', 'Kansai Uluslararası Havalimanı', 'Osaka', 'Japonya'),
  ('KRK', 'John Paul II Uluslararası Havaalanı', 'Krakow', 'Polonya'),
  ('KRT', 'Hartum Havalimanı', 'Hartum', 'Sudan'),
  ('KTM', 'Tribhuvan Uluslararası Havalimanı', 'Katmandu', 'Nepal'),
  ('KUL', 'Kuala Lumpur Uluslararası Havalimanı', 'Kuala Lumpur', 'Malezya'),
  ('KWI', 'Kuveyt Uluslararası Havalimanı', 'Kuveyt', 'Kuveyt'),
  ('KZN', 'Kazan Uluslararası Havalimanı', 'Kazan', 'Rusya'),
  ('LAD', 'Quatro de Fevereiro Havalimanı', 'Luanda', 'Angola'),
  ('LAX', 'Los Angeles Uluslararası Havalimanı', 'Los Angeles', 'ABD'),
  ('LBV', 'Léon M''ba Uluslararası Havalimanı', 'Libreville', 'Gabon'),
  ('LED', 'Pulkovo Havalimanı', 'St. Petersburg', 'Rusya'),
  ('LGW', 'Gatwick Havalimanı', 'Londra', 'Birleşik Krallık (İngiltere)'),
  ('LHE', 'Allame İkbal Uluslararası Havalimanı', 'Lahor', 'Pakistan'),
  ('LHR', 'Heathrow Havalimanı', 'Londra', 'Birleşik Krallık (İngiltere)'),
  ('LIS', 'Lizbon Poertela Havalimanı', 'Lizbon', 'Portekiz'),
  ('LJU', 'Joze Pucnik Havalimanı', 'Lübliyana', 'Slovenya'),
  ('LOS', 'Murtala Muhammed Uluslararası Havalimanı', 'Lagos', 'Nijerya'),
  ('LUN', 'Kenneth Kaunda Uluslararası Havalimanı', 'Lusaka', 'Zambiya'),
  ('LUX', 'Luxembourg Findel International Airport', 'Luxembourg', 'Lüksemburg'),
  ('LYS', 'Saint Exupery Havalimanı', 'Lyon', 'Fransa'),
  ('MAD', 'Barajas Uluslararası Havalimanı', 'Madrid', 'İspanya'),
  ('MAN', 'Manchester Havalimanı', 'Manchester', 'Birleşik Krallık (İngiltere)'),
  ('MCT', 'Maskat Uluslararası Havalimanı', 'Maskat', 'Umman'),
  ('MED', 'Prens Muhammed Bin Abdülaziz Havalimanı', 'Medine', 'Suudi Arabistan'),
  ('MEL', 'Tullamarine Havalimanı', 'Melbourne', 'Avustralya'),
  ('MEX', 'Benito Juarez Uluslararası Havalimanı', 'Mexico City', 'Meksika'),
  ('MIA', 'Miami Uluslararası Havalimanı', 'Miami', 'ABD'),
  ('MLA', 'Luqa Havalimanı', 'Malta', 'Malta'),
  ('MLE', 'Valena (Velana) Uluslararası Havalimanı', 'Male', 'Maldivler'),
  ('MNL', 'Ninoy Aquino Uluslararası Havalimanı', 'Manila', 'Filipinler'),
  ('MPM', 'Maputo Uluslararası Havalimanı', 'Maputo', 'Mozambik'),
  ('MRA', 'Misrata Uluslararası Havalimanı (MRA)', 'Misrata', 'Libya'),
  ('MRS', 'Marsilya Provence Havalimanı', 'Marsilya', 'Fransa'),
  ('MRU', 'Sir Seewoosagur Ramgoolam Uluslararası Havalimanı', 'Port Louis', 'Mauritius'),
  ('MUC', 'Münih Uluslararası Havalimanı', 'Münih', 'Almanya'),
  ('MXP', 'Malpensa Havalimanı', 'Milano', 'İtalya'),
  ('NAP', 'Napoli Uluslararası Havalimanı', 'Napoli', 'İtalya'),
  ('NBO', 'Nairobi Jomo Kenyatta Uluslararası Havalimanı', 'Nairobi', 'Kenya'),
  ('NCE', 'Cote d''Azur Uluslararası Havalimanı', 'Nice', 'Fransa'),
  ('NDJ', 'Encemine Havalimanı', 'Encemine (N''Djamena)', 'Çad'),
  ('NIM', 'Diori Hamani Uluslararası Havalimanı', 'Niamey', 'Nijer'),
  ('NKC', 'Nuakşot Havalimanı', 'Nuakşot', 'Moritanya'),
  ('NRT', 'Narita Uluslararası Havalimanı', 'Tokyo (Narita)', 'Japonya'),
  ('NSI', 'Yaunde Uluslararası Havalimanı', 'Yaunde', 'Kamerun'),
  ('NUE', 'Nürnberg Havalimanı', 'Nürnberg', 'Almanya'),
  ('OHD', 'Ohrid St. Paul the Apostle Airport', 'Ohri', 'Kuzey Makedonya'),
  ('OPO', 'Francisco Sa Carneiro Havalimanı', 'Porto', 'Portekiz'),
  ('ORD', 'O''Hare Uluslararası Havalimanı', 'Şikago', 'ABD'),
  ('ORN', 'Oran Ahmed Ben Bella Havalimanı', 'Oran', 'Cezayir'),
  ('OSL', 'Gardermoen Havalimanı', 'Oslo', 'Norveç'),
  ('OTP', 'Henri Coanda Uluslararası Havalimanı', 'Bükreş', 'Romanya'),
  ('OUA', 'Vagadugu Havalimanı', 'Vagadugu', 'Burkina Faso'),
  ('PEK', 'Pekin Başkent Uluslararası Havalimanı', 'Pekin', 'Çin'),
  ('PMO', 'Falcone Borsellino Havalimanı', 'Palermo', 'İtalya'),
  ('PNH', 'Phnom Penh Uluslararası Havalimanı', 'Phnom Penh', 'Kamboçya'),
  ('PNR', 'Pointe-Noire Havalimanı', 'Pointe-Noire', 'Kongo'),
  ('PRG', 'Vaclac Havel Havalimanı', 'Prag', 'Çekya'),
  ('PRN', 'Priştine Uluslararası Havalimanı', 'Priştine', 'Kosova'),
  ('PTY', 'Tocumen Uluslararası Havalimanı', 'Panama', 'Panama'),
  ('PVG', 'Pudong Uluslararası Havalimanı', 'Şanghay', 'Çin'),
  ('RAK', 'Marrakech Menara Havalimanı', 'Marakeş', 'Fas'),
  ('RIX', 'Riga Uluslararası Havalimanı', 'Riga', 'Letonya'),
  ('RUH', 'King Khalid Uluslararası Havalimanı', 'Riyad', 'Suudi Arabistan'),
  ('RZV', 'Rize-Artvin Havalimanı', 'Rize / Artvin', 'Türkiye'),
  ('SAW', 'İstanbul Sabiha Gökçen Uluslararası Havalimanı', 'İstanbul', 'Türkiye'),
  ('SCL', 'Arturo Merino Benitez Havalimanı', 'Santiago', 'Şili'),
  ('SEA', 'Seattle-Tacoma Uluslararası Havalimanı', 'Seattle', 'ABD'),
  ('SEZ', 'Seyşeller Uluslararası Havalimanı', 'Seyşeller', 'Seyşeller'),
  ('SFO', 'San Francisco Uluslararası Havalimanı', 'San Francisco', 'ABD'),
  ('SGN', 'Tan Son Nhat Uluslararası Havalimanı', 'Ho Chi Minh', 'Vietnam'),
  ('SHJ', 'Şarika Havalimanı', 'Şarika', 'Birleşik Arap Emirlikleri'),
  ('SIN', 'Singapur Changi Havalimanı', 'Singapur', 'Singapur'),
  ('SJJ', 'Saraybosna Uluslararası Havalimanı', 'Saraybosna', 'Bosna Hersek'),
  ('SKG', 'Selanik Makedonya Havalimanı', 'Selanik', 'Yunanistan'),
  ('SKP', 'Üsküp Uluslararası Havalimanı', 'Üsküp', 'Kuzey Makedonya'),
  ('SOF', 'Sofya Uluslararası Havalimanı', 'Sofya', 'Bulgaristan'),
  ('SSH', 'Şarm El-Şeyh Uluslararası Havalimanı', 'Şarm El-Şeyh', 'Mısır'),
  ('STR', 'Stuttgart Havalimanı', 'Stuttgart', 'Almanya'),
  ('SZG', 'Wolfgang Amadeus Mozart Havalimanı', 'Salzburg', 'Avusturya'),
  ('TAS', 'İslam Kerimov Taşkent Uluslararası Havalimanı', 'Taşkent', 'Özbekistan'),
  ('TBS', 'Tiflis Havalimanı', 'Tiflis', 'Gürcistan'),
  ('TBZ', 'Tebriz Havalimanı', 'Tebriz', 'İran'),
  ('TIA', 'Tiran Uluslararası Havalimanı', 'Tiran', 'Arnavutluk'),
  ('TIF', 'Taif Bölgesel Havaalanı', 'Taif', 'Suudi Arabistan'),
  ('TLL', 'Lennart Meri Tallinn Havalimanı', 'Tallinn', 'Estonya'),
  ('TLS', 'Toulouse-Blagnac Havalimanı', 'Toulouse', 'Fransa'),
  ('TNR', 'Ivato Uluslararası Havalimanı', 'Antananarivo', 'Madagaskar'),
  ('TPE', 'Taoyuan Uluslararası Havalimanı', 'Taoyuan (Taipei)', 'Tayvan'),
  ('TRN', 'Torino Havalimanı', 'Torino', 'İtalya'),
  ('TSR', 'Timisoara Traian Vuia Uluslararası Havalimanı', 'Temeşvar', 'Romanya'),
  ('TUN', 'Kartaca Havalimanı', 'Tunus', 'Tunus'),
  ('TZX', 'Trabzon Uluslararası Havalimanı', 'Trabzon', 'Türkiye'),
  ('UBN', 'Cengiz Han Uluslararası Havalimanı', 'Ulanbator', 'Moğolistan'),
  ('VAR', 'Varna Havalimanı', 'Varna', 'Bulgaristan'),
  ('VCE', 'Marco Polo Havalimanı', 'Venedik', 'İtalya'),
  ('VIE', 'Viyana Uluslararası Havalimanı', 'Viyana', 'Avusturya'),
  ('VKO', 'Moskova Vnukovo Uluslararası Havalimanı', 'Moskova', 'Rusya'),
  ('VLC', 'Valensiya Havalimanı', 'Valensiya', 'İspanya'),
  ('VNO', 'Vilnius Uluslararası Havalimanı', 'Vilnius', 'Litvanya'),
  ('WAW', 'Chopin Uluslararası Havalimanı', 'Varşova', 'Polonya'),
  ('YUL', 'Montreal-Pierre Elliot Trudeau Uluslararası Havalimanı', 'Montreal', 'Kanada'),
  ('YVR', 'Vancouver Uluslararası Havalimanı', 'Vancouver', 'Kanada'),
  ('YYZ', 'Lester B. Pearson Uluslararası Havalimanı', 'Toronto', 'Kanada'),
  ('ZAG', 'Zagreb Havalimanı', 'Zagreb', 'Hırvatistan'),
  ('ZNZ', 'Abeid Amani Karume Uluslararası Havalimanı', 'Zanzibar', 'Tanzanya'),
  ('ZRH', 'Zürih Kloten Havalimanı', 'Zürih', 'İsviçre')
on conflict (code) do update set
  name    = coalesce(nullif(excluded.name, ''), airports.name),
  city    = coalesce(nullif(excluded.city, ''), airports.city),
  country = coalesce(nullif(excluded.country, ''), airports.country);

-- ---- 2) SALONLAR (lounge_venues) ----
-- scope: 'abroad' BURAYA yazilmaz — lounge_venues.scope kisiti yalniz
-- domestic/international/both kabul eder ve resolve_guest_rule kapsami
-- airports.country'den TURETIR (172:58). Yurt disi salonlar 'both'.
insert into lounge_venues (airport_code, name, terminal, section, operator, scope, notes, active) values
  ('IST', 'İstanbul Havalimanı dış hatlar özel yolcu salonu — Business Lounge', 'Dış Hatlar', 'business', 'Turkish Airlines', 'international', '24 saat açık. Business Lounge''da müze. Suit hakkı: ücretli Business Class veya Elit Plus kart + 4-9 saat bekleme + en az bir uçuş 8 saat ve üzeri, her iki uçuş da THY dış hat, aynı bilet üzerinde', true),
  ('IST', 'İstanbul Havalimanı dış hatlar özel yolcu salonu — Miles&Smiles Lounge', 'Dış Hatlar', 'miles_smiles', 'Turkish Airlines', 'international', '24 saat açık. M&S Lounge''da sinema ve masör. Duş, süit, toplantı odası, çocuk oyun alanı', true),
  ('IST', 'İstanbul Havalimanı iç hatlar özel yolcu salonu — Business Lounge', 'İç Hatlar', 'business', 'Turkish Airlines', 'domestic', '24 saat açık. Kullanım süresi 4 saat, uçuştan 4 saat önce başlar; gecikmede devam eder', true),
  ('IST', 'İstanbul Havalimanı iç hatlar özel yolcu salonu — Miles&Smiles Lounge', 'İç Hatlar', 'miles_smiles', 'Turkish Airlines', 'domestic', '24 saat açık. Kullanım süresi 4 saat, uçuştan 4 saat önce başlar; gecikmede devam eder', true),
  ('SAW', 'Sabiha Gökçen iç hatlar özel yolcu salonu', 'VIP Terminali ve Sabiha Gökçen Metro İstasyonu yanı', null, 'Turkish Airlines', 'domestic', '04.00-01.00 açık, 01.00-04.00 KAPALI. Kullanım 3 saat, uçuştan 2 saat önce başlar', true),
  ('COV', 'Çukurova Uluslararası Havalimanı iç hatlar özel yolcu salonu', 'İç Hatlar (Güvenlik sonrası)', null, 'Turkish Airlines', 'domestic', 'kod SS''te yok. Sefer saatlerine göre açık. Kullanım 3 saat, uçuştan 2 saat önce başlar [188: IATA kodu COV olarak eslendi]', true),
  ('AYT', 'Antalya Havalimanı iç hatlar özel yolcu salonu', 'İç Hatlar – Gidiş', null, 'Turkish Airlines', 'domestic', '24 saat. Kullanım 3 saat, uçuştan 2 saat önce başlar. Ayrı check-in ve bilet satışı', true),
  ('AYT', 'Antalya Havalimanı dış hatlar özel yolcu salonu (FTA CIP Salonları)', 'Uçuş operasyonunun yapıldığı terminaldeki FTA CIP Salonları', null, 'Fraport TAV Antalya (FTA) CIP', 'international', '24 saat. Kullanım süresi 4 saat. Ayrı check-in, ayrı bilet satışı, ayrı boarding', true),
  ('ESB', 'Ankara Esenboğa Havalimanı iç hatlar özel yolcu salonu', 'Ayrı terminal', null, 'Turkish Airlines', 'domestic', '24 saat. Kullanım 3 saat, uçuştan 2 saat önce başlar. Ayrı check-in / bilet satışı / boarding', true),
  ('ADB', 'İzmir Adnan Menderes Havalimanı iç hatlar özel yolcu salonu', 'Ayrı terminal', null, 'Turkish Airlines', 'domestic', '01:00-23:00 açık (23:00-01:00 kapalı). Kullanım 3 saat, uçuştan 2 saat önce başlar', true),
  ('BJV', 'Milas-Bodrum Havalimanı iç hatlar özel yolcu salonu', 'İç Hatlar – Gidiş', null, 'Turkish Airlines', 'domestic', 'Kış sezonu 07.00-23.00; Yaz sezonu 24 saat. Kullanım 3 saat, uçuştan 2 saat önce başlar', true),
  ('HTY', 'Hatay Havalimanı iç hatlar özel yolcu salonu', 'İç Hatlar', null, 'Turkish Airlines', 'domestic', 'Sefer saatine göre. Kullanım 3 saat, uçuştan 2 saat önce başlar', true),
  ('ASR', 'Kayseri Havalimanı iç hatlar özel yolcu salonu', 'CIP Terminal Binası', null, 'Turkish Airlines', 'domestic', '24 saat. Kullanım 3 saat, uçuştan 2 saat önce başlar', true),
  ('TZX', 'Trabzon Uluslararası Havalimanı iç hatlar özel yolcu salonu', 'Ayrı CIP Terminali', null, 'Turkish Airlines', 'domestic', '24 saat. Kullanım 3 saat, uçuştan 2 saat önce başlar. Sigara içme alanı var', true),
  ('RZV', 'Rize-Artvin Havalimanı iç hatlar özel yolcu salonu', 'CIP Terminali', null, 'Turkish Airlines', 'domestic', 'Sefer saatine göre. Kullanım süresi 2 SAAT (diğerlerinden farklı), uçuştan 2 saat önce başlar', true),
  ('GZT', 'Gaziantep Havalimanı iç hatlar özel yolcu salonu', 'Ayrı CIP Terminali', null, 'Turkish Airlines', 'domestic', '24 saat. Kullanım 3 saat, uçuştan 2 saat önce başlar', true),
  ('JFK', 'Turkish Airlines Lounge', 'Terminal 1 (2 ve 3 nolu kapıların arasında)', null, 'Turkish Airlines', 'both', '09:45-23:45. Duş, mescit, toplantı masası, IFE hizmeti. Anlaşmalı listede de var (saatler farklı yazılmış: 03:00-07:00 ve 09:00-00:00) · Hizmet saatleri: 03:00-07:00 açık ; 09:00-00:00 açık. THY''nin kendi salonu; yurtdışı listesinde 09:45-23:45 yazıyor — saat çelişkisi', true),
  ('MIA', 'Turkish Airlines Lounge (Concourse E)', 'Central Terminal – Concourse E (güvenlik kontrolünden sonra)', null, 'Turkish Airlines', 'both', '06:00-00:00. Duş, çocuk odası, mescit', true),
  ('MIA', 'Turkish Airlines Lounge (Concourse H)', 'Central Terminal – Concourse H (güvenlik kontrolünden sonra)', null, 'Turkish Airlines', 'both', '05.00-02.00. Duş, çocuk odası, mescit', true),
  ('IAD', 'Turkish Airlines Lounge', 'B Terminali (B43 numaralı kapının yanı)', null, 'Turkish Airlines', 'both', '07.15-21.30. Anlaşmalı listede 7:00-23:00 yazıyor — saat çelişkisi var · Hizmet saatleri: 7:00 - 23:00. THY''nin kendi salonu; yurtdışı listesinde 07.15-21.30 — saat çelişkisi', true),
  ('VKO', 'Turkish Airlines Lounge (Istanbul-Moscow)', 'Terminal A (pasaport kontrolü sonrası 2. kat Lounge alanı)', null, 'Turkish Airlines', 'both', '24 saat. Bilardo ve kütüphane var. Anlaşmalı listede ''Istanbul-Moscow'' adıyla geçiyor', true),
  ('EDI', 'Turkish Airlines Lounge', 'Havalimanı Kat 2, 16 Nolu kapı yanı / Ana Terminal', null, 'Turkish Airlines', 'both', '04:00-22:00. Anlaşmalı listede İskoçya başlığı altında da var · Hizmet saatleri: 04:00 - 22:00. THY''nin kendi salonu; yurtdışı listesinde de var', true),
  ('NRT', 'Turkish Airlines Lounge', 'Güney Kanadı, Ek Terminal 4, Kapı 47 (anlaşmalı listede: Terminal 1, Uydu 4, Kapı 47)', null, 'Turkish Airlines', 'both', '7.30-21.45. Duş odası saatleri 7:30-20:30 · Hizmet saatleri: 07:30 - 21:45 (Lokal Saat). THY''nin kendi salonu; yurtdışı listesinde de var', true),
  ('BKK', 'Turkish Airlines Lounge', 'Concourse D, D8 kapısını geçince sağda / Uluslararası Terminal', null, 'Turkish Airlines', 'both', '24 saat. 15 dk ücretsiz masaj, uyku alanı, VIP oda', true),
  ('NBO', 'Turkish Airlines Lounge (Star Alliance)', 'Terminal 1E (3 numaralı kapının yanı)', null, 'Turkish Airlines', 'both', '24 saat. Duş, çocuk odası, mescit', true),
  ('KBL', 'Business', 'Uluslararası Terminal', null, null, 'both', 'Hizmet saatleri: 6:30 - 17:00', true),
  ('BER', 'Lufthansa Star Alliance Lounge', '1. Terminal', null, 'Lufthansa', 'both', 'Hizmet saatleri: 5:00 - 20:30', true),
  ('BER', 'Tempelhof', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 21:00', true),
  ('BRE', 'LUFTHANSA', '1. Terminal', null, 'Lufthansa', 'both', 'Hizmet saatleri: 5:00 - 21:00', true),
  ('BRE', 'The Lounge', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: 5:00 - 21:00', true),
  ('DUS', 'Open Sky', 'A-B-C Terminalleri', null, null, 'both', 'Hizmet saatleri: 4:00 - 19:40', true),
  ('FRA', 'Lufthansa Business B-Ost', '1. Terminal', null, 'Lufthansa', 'both', 'Hizmet saatleri: 6:00 - 14:00', true),
  ('FRA', 'Lufthansa Business B-West', '1. Terminal', null, 'Lufthansa', 'both', 'Hizmet saatleri: 6:00 - 21:30', true),
  ('FRA', 'Lufthansa Senator B', '1. Terminal', null, 'Lufthansa', 'both', 'Hizmet saatleri: 6:00 - 21:30', true),
  ('FRA', 'Ac Maple Leaf', '1. Terminal', null, 'Air Canada', 'both', 'Hizmet saatleri: 6:00 - 16:30', true),
  ('HAM', 'Hamburg Airport Lounge', 'Terminal 1 ve Terminal 2 arası', null, null, 'both', 'Hizmet saatleri: Cumartesi 05:30-16:00; Diğer günler 05:30-21:00', true),
  ('HAM', 'Business Lounge', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat. SS''te Hamburg iki farklı havalimanı adıyla listelenmiş (Fhulsbuttel / Hamburg Uluslararası) — aynı havalimanı', true),
  ('HAJ', 'Melli Beese', 'C Terminali', null, null, 'both', 'Hizmet saatleri: 5:30 - 21:00', true),
  ('CGN', 'The Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('MUC', 'Havalimanı Lounge World', '1/B Terminali', null, null, 'both', 'Hizmet saatleri: 5:15 - 20:30', true),
  ('NUE', 'Dürer', 'Güvenlik Sonrası (Pasaport Kontrolü Öncesi)', null, null, 'both', 'Hizmet saatleri: 4:00 - 19:00', true),
  ('STR', 'Airport Lounge', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 05:00 - 21:30', true),
  ('ATL', 'The Club', 'Concourse F Terminali', null, null, 'both', 'Hizmet saatleri: 6:00 - 22:00', true),
  ('BOS', 'Lufthansa', 'E Terminali', null, 'Lufthansa', 'both', 'Hizmet saatleri: 12:15-21:30', true),
  ('DFW', 'Capital One', 'D Terminali (D22 Kapısı Yanı)', null, null, 'both', 'Hizmet saatleri: 6:00 - 21:00', true),
  ('DEN', 'United Airlines Lounge', '5. Terminali', null, 'United Airlines', 'both', 'Hizmet saatleri: 6:30 - 20:00', true),
  ('DTW', 'Lufthansa Lounge', 'Evans Terminali', null, 'Lufthansa', 'both', 'Hizmet saatleri: Uçuş Saatlerinde', true),
  ('IAH', 'United', 'E Terminali', null, 'United Airlines', 'both', 'Hizmet saatleri: 6:00 - 22:00', true),
  ('LAX', 'Star Alliance', 'Tom Bradley / B Terminali', null, 'Star Alliance', 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('MIA', 'Turkish Airlines Lounge', 'Concourse E', null, 'Turkish Airlines', 'both', 'Hizmet saatleri: 06:00 – 00:00. THY''nin kendi salonu; yurtdışı listesinde de var · Hizmet saatleri: 05:00 – 02:00. THY''nin kendi salonu; yurtdışı listesinde de var', true),
  ('EWR', 'Air France', 'B Terminali', null, 'Air France', 'both', 'Hizmet saatleri: 21:00 – 24:00', true),
  ('SFO', 'United Club', 'Uluslararası G Terminali', null, 'United Airlines', 'both', 'Hizmet saatleri: 7:00 - 22:30', true),
  ('SFO', 'The Club Lounge', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: 4.30 - 23.30', true),
  ('SFO', 'United Polaris', 'Uluslararası G Terminali', null, 'United Airlines', 'both', 'Hizmet saatleri: 6:30 - 22:30', true),
  ('SEA', 'Club At Seattle', 'Güney Satellite Concourse Terminali', null, null, 'both', 'Hizmet saatleri: 6:00 - 19:00', true),
  ('ORD', 'Swissport', '5. Terminal', null, 'Swissport', 'both', 'Hizmet saatleri: 7:00 - 21:30', true),
  ('ORD', 'LOT Business Lounge', '5. Terminal', null, 'LOT', 'both', 'Hizmet saatleri: 8:00-00:00', true),
  ('LAD', 'MENZIES AIRPORT', '1. Terminal', null, 'Menzies', 'both', 'Hizmet saatleri: 5:00 - 20:00', true),
  ('TIA', 'Business Lounge', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('EZE', 'Star Alliance Lounge', 'T1', null, 'Star Alliance', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('MEL', 'Air New Zealand', '2. Terminal', null, 'Air New Zealand', 'both', 'Hizmet saatleri: 05:00 - 00:00', true),
  ('SZG', 'Business', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 06.00-21.00', true),
  ('VIE', 'Viyana Lounge', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: 04.30-22.00', true),
  ('GYD', 'Business Class', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('BAH', 'Pearl Lounge', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('DAC', 'EBL Sky Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BRU', 'Diamond', 'Non schengen Terminali', null, null, 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('COO', 'Lounge Ahs', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('AUH', 'Pearl Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SHJ', 'The Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('DXB', 'Marhaba Lounge', '1. Terminal', null, 'Marhaba', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SJJ', 'Business Lounge', 'B Terminali', null, null, 'both', 'Hizmet saatleri: 05:00-22:00', true),
  ('GRU', 'Espaco Banco Safra Lounge', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 23:00 - 02:00', true),
  ('VAR', 'Business', '2. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SOF', 'PrimeClass Lounge', '2. Terminal', null, 'Primeclass', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('OUA', 'Yennenga Lounge', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('OUA', 'Salon CIP', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('OUA', 'Servair Lounge', 'Ana Terminal', null, 'Servair', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('ALG', 'Salon Sgsia', '2. Salon', null, null, 'both', 'Hizmet saatleri: Uçuş Saatleri', true),
  ('ORN', 'Air Algerie', '1. Terminali', null, 'Air Algerie', 'both', 'Hizmet saatleri: Uçuş Saatleri', true),
  ('ALG', 'Air Algerie Catering', 'Terminal 4', null, 'Air Algerie', 'both', 'Hizmet saatleri: Uçuş Saatleri', true),
  ('NDJ', 'Tchad Handling Services LTD.', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('CAN', 'Star Alliance Lounge', '1. Terminaller', null, 'Star Alliance', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('PEK', 'Air China Lounge', '3E Terminali', null, 'Air China', 'both', 'Hizmet saatleri: 06:00 - 22:00', true),
  ('PVG', 'Air China Business 71', '2. Terminal', null, 'Air China', 'both', 'Hizmet saatleri: 06.00-02.00', true),
  ('JIB', 'Salon CIP', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('PRG', 'Master Card', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 5:30 - 23:00', true),
  ('FIH', 'Salon VIP', 'Uluslararası Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BLL', 'King Amlet', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: Ulusal tatillere veya mevsimlere göre değişir', true),
  ('CPH', 'Pearl Lounge', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 05.30 - 20.00', true),
  ('CGK', 'PLAZA PREMIUM LOUNGE', '3. Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: Pzt 03:00-11:00/15:00-24:00; Sal 03:00-24:00; Çar 04:00-11:00/13:00-24:00; Per 04:00-14:00/16:00-24:00; Cum 03:00-11:00/15:00-24:00; Cmt 00:00-14:00/16:00-24:00; Paz 04:00-14:00/16:00-24:00', true),
  ('DPS', 'Tujuwan Lounge', 'Dış Hatlar Gidiş Terminali', null, null, 'both', 'Hizmet saatleri: 04.00 – 02.00 yerel saat', true),
  ('TLL', 'Airport LHV Lounge', 'Yolcu terminalinin 2. katı (Shengen Bölgesi)', null, null, 'both', 'Hizmet saatleri: Pzt-Pzr 4:30 - 22:00', true),
  ('ADD', 'Cloud Nine', '2. Terminal', null, 'Ethiopian Airlines', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('CMN', 'Le Zénith I', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: 7/24 hours', true),
  ('RAK', 'Oasis (RAM) Lounge', 'Terminal 1', null, 'Royal Air Maroc', 'both', 'Hizmet saatleri: 7/24 hours', true),
  ('ABJ', 'Aeria VIP', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('CEB', 'Plaza Premium', '2. Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: 1:00-14:00 (Pzt, Çar, Cum); 8:00-14:00 (Sal, Per, Cmt, Paz)', true),
  ('MNL', 'Paggs', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('HEL', 'Plaza Premium Lounge', '2. Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: Pazartesi 10:00-19:30; Diğer günler 06:00-19:30', true),
  ('BOD', 'Myairport Lounge Hall', 'A Terminali', null, null, 'both', 'Hizmet saatleri: 11:30-14:00', true),
  ('LYS', 'Mont Blanc', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7:30 - 21:30', true),
  ('MRS', 'Cézanne Lounge', 'Terminal 1B', null, null, 'both', 'Hizmet saatleri: 05.00-22.10', true),
  ('NCE', 'The Canopy Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 6:00 - 21:00', true),
  ('CDG', 'Star Alliance Lounge', '1. Terminal', null, 'Star Alliance', 'both', 'Hizmet saatleri: 05:30 - 22:00', true),
  ('TLS', 'La Croix Du Sud Lounge', 'Salon C', null, null, 'both', 'Hizmet saatleri: Pzt-Cuma 5:15-21:00; Cmt 05:15-20:00; Pazar 05:45-21:00', true),
  ('LBV', 'Salon Samba', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Günün son uçuşuna kadar', true),
  ('ACC', 'Sanbra Priority', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 01:00', true),
  ('BJL', 'Roumieh', 'Uluslararası Gidiş Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('CKY', 'Salon Nimba', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Paz 6:00-12:00; Pzt 12:00-00:00; Sal 14:00-2:00; Çar 18:00-12:00; Per 7:00-16:00; Cum 6:00-12:00; Cmt 3:00-21:00', true),
  ('CPT', 'Bidvest Premier', 'Dış Hatlar Terminali', null, 'Bidvest', 'both', 'Hizmet saatleri: 04:00 - 00:30', true),
  ('DUR', 'Umphafa', 'International Terminal', null, null, 'both', 'Hizmet saatleri: 07:00 - 21:00', true),
  ('JNB', 'Saa Preminium', 'A Terminali', null, 'South African Airways', 'both', 'Hizmet saatleri: 7:00 - 23:30', true),
  ('ICN', 'Asiana', '1. Terminal', null, 'Asiana Airlines', 'both', 'Hizmet saatleri: 06.00-00.30', true),
  ('BUS', 'Primeclass', 'Ana Terminal', null, 'Primeclass', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('TBS', 'Primeclass', 'Gidiş Terminali', null, 'Primeclass', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('AMS', 'Aspire Lounge', 'Ana Bina Terminali', null, 'Aspire', 'both', 'Hizmet saatleri: 06:00 - 22:00', true),
  ('HKG', 'Plaza Premium', '1. Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('DBV', 'Business', 'C Terminali', null, null, 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('ZAG', 'Prime Class', 'Uluslararası Gidiş Terminali', null, 'Primeclass', 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('BOM', 'Adani', '2. Terminal', null, 'Adani', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('DEL', 'Encalm Lounge', '3. Terminal', null, 'Encalm', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BGW', 'Bağdat Lounge', '1. Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BSR', 'Royal', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('EBL', 'Newroz Business Class', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BHX', 'Lounges 1', 'Hava Sahası', null, null, 'both', 'Hizmet saatleri: 5:00 - 21:00', true),
  ('LGW', 'Lounge 1', 'Güney Terminali', null, null, 'both', 'Hizmet saatleri: 4:00 - 21:00. Giriş penceresi: uçuştan en fazla 180 dk ve en az 30 dk önce', true),
  ('LHR', 'Air Canada', '2B Terminali', null, 'Air Canada', 'both', 'Hizmet saatleri: 7:00 - 20:00', true),
  ('LHR', 'Singapore Airlines', '2B Terminali', null, 'Singapore Airlines', 'both', 'Hizmet saatleri: 5:30 - 22:00', true),
  ('LHR', 'Lufthansa', '2A Terminali', null, 'Lufthansa', 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('LHR', 'United Airlines', '2B Terminali', null, 'United Airlines', 'both', 'Hizmet saatleri: 5:00 - 18:00', true),
  ('MAN', 'Aspire Lounge', '2. Terminal', null, 'Aspire', 'both', 'Hizmet saatleri: 04:00 - 22:00', true),
  ('TBZ', 'International CIP', 'Yakın Uluslararası Gidiş Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BCN', 'VIP Joan Miró', 'T1 Terminali', null, null, 'both', 'Hizmet saatleri: 5:00 - 23:00', true),
  ('BIO', 'Sala VIP', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 5:30 - 22:15', true),
  ('MAD', 'Cibeles VIP', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('AGP', 'Sala VIP T3', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 5:30 - 22:30', true),
  ('VLC', 'Joan Olivert', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 23:00', true),
  ('GOT', 'Menzies', 'Uluslararası Terminal', null, 'Menzies', 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('BSL', 'Skyview', 'Y Terminali', null, null, 'both', 'Hizmet saatleri: 5:30 - 20:30. Havalimanı BSL/MLH/EAP kodlarıyla da anılır', true),
  ('GVA', 'Aspire Lounge', 'Ana Terminal Binası', null, 'Aspire', 'both', 'Hizmet saatleri: 06:30 - 01:30', true),
  ('GVA', 'Swiss Star', '1. Terminal', null, 'Swiss', 'both', 'Hizmet saatleri: 6:00 - 20:30', true),
  ('ZRH', 'Aspire Lounge', 'E Terminali', null, 'Aspire', 'both', 'Hizmet saatleri: 6:00 - 22:00', true),
  ('BRI', 'Executive', 'Hava Sahası / Biniş Alanı', null, null, 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('BLQ', 'Marconi', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 21:00. TADİLAT DOLAYISIYLA GEÇİCİ OLARAK KAPALI', true),
  ('CTA', 'Lounge Sac', 'A Terminali', null, null, 'both', 'Hizmet saatleri: 6:30 - 21:00', true),
  ('MXP', 'Montale Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('NAP', 'Pearl', '1. Terminal (C17-C19 Kapıları Yanı)', null, null, 'both', 'Hizmet saatleri: 5:00 - 21:00', true),
  ('PMO', 'Prima Vista Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş Saatleri', true),
  ('FCO', 'Plaza Premium', '3. Terminal - Gidiş Kısmı', null, 'Plaza Premium', 'both', 'Hizmet saatleri: 5:30 - 22:30', true),
  ('TRN', 'SAGAT S.p.A Havalimanı', '1. Terminal', null, 'SAGAT', 'both', 'Hizmet saatleri: 05.00 – 21.00 (yerel saat)', true),
  ('VCE', 'Marco Polo', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 5:00 - 22:00', true),
  ('KIX', 'KANSAI Airport Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('HND', 'Lounge ANA', '3. Terminal', null, 'ANA', 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('PNH', 'Plaza Premium lounge', 'Uluslararası Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: Uçuş zamanları. Plaza Premium — SS''te şehir hücresinde ''Kamboçya'' yazıyor', true),
  ('DLA', 'Mtn Lounge Doualair', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş Saatleri', true),
  ('NSI', 'Salon Privatif', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('YUL', 'Maple Leaf Lounge', 'Uluslararası Terminal', null, 'Air Canada', 'both', 'Hizmet saatleri: 04:30 – 23:15', true),
  ('YYZ', 'Ac Maple Leaf', '1. Terminal', null, 'Air Canada', 'both', 'Hizmet saatleri: 6:00 - 00:45', true),
  ('YVR', 'Skyteam', 'Uluslararası Gidiş Terminali', null, 'SkyTeam', 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('DOH', 'Oryx', 'Ana Terminal', null, 'Qatar Airways', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('ALA', 'Extime Lounge', 'International Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('NBO', 'Turkish Airlines Star Alliance', '1E Terminali', null, 'Turkish Airlines', 'both', 'Hizmet saatleri: 7 gün 24 saat. THY''nin kendi salonu; yurtdışı listesinde de var', true),
  ('FRU', 'Business Lounge', '(SS''te ''-'' yazıyor)', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat. Bölge/terminal bilgisi SS''te boş', true),
  ('ECN', 'PARAMARIBO', '1. Terminal, 2. kat', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BOG', 'Avianca VIP', 'Uluslararası Terminal', null, 'Avianca', 'both', 'Hizmet saatleri: 4:00 - 23:00', true),
  ('BOG', 'Copa Club', '1. Terminal', null, 'Copa Airlines', 'both', 'Hizmet saatleri: 3:00 - 21:00', true),
  ('PNR', 'Salon Ebene', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('PRN', 'Lounge 1702', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('KWI', 'Dasman Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('HAV', 'Salon CIP', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('RIX', 'Primeclass Riga Business', 'E Terminali', null, 'Primeclass', 'both', 'Hizmet saatleri: 6:00 - 23:00', true),
  ('BEY', 'Ahlein', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('MRA', 'Altaie Company Lounge', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('VNO', 'Narbutas Business', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 4:00 - 22:00', true),
  ('LUX', 'Luxair Lounge', 'A Terminali', null, 'Luxair', 'both', 'Hizmet saatleri: Cumartesi 04.00-18.00; Diğer günler 04.00-21.00', true),
  ('BUD', 'Platinum Lounge', '1. Terminali', null, null, 'both', 'Hizmet saatleri: 05:00 - 20:00', true),
  ('TNR', 'Prime Class', 'C Terminali', null, 'Primeclass', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SKP', 'TAV Primeclass Lounge', 'Tek Terminal', null, 'TAV Primeclass', 'both', 'Hizmet saatleri: 7 Gün / 24 Saat', true),
  ('OHD', 'Primeclass CIP Lounge', 'International Terminal', null, 'Primeclass', 'both', 'Hizmet saatleri: 09:00 – 18:00', true),
  ('MLE', 'Leeli', 'Uluslararası Terminal', null, null, 'both', 'Hizmet saatleri: 6:00 - 23:30', true),
  ('KUL', 'Global Lounge', 'KLIA 1. Terminali Satellite', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BKO', 'Bravia Platinum', '1. Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('MLA', 'Salon CIP', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('MRU', 'Les Salons Amedee Maingard', 'Terminal 1 (28 numaralı gate karşısı)', null, null, 'both', 'Hizmet saatleri: 06:00-23:00', true),
  ('CUN', 'VIP Lounge by Mera', 'Terminal 4 - 67A Kapısı yanı', null, null, 'both', 'Hizmet saatleri: 6:30 – 21:30', true),
  ('MEX', 'United Airlines United club', 'Uluslararası Gidiş Terminali', null, 'United Airlines', 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('HRG', 'NATIONAL LOGISTICS SAE.', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('HBE', 'NATIONAL LOGISTICS SAE.', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('CAI', 'Egyptair', '3. Terminal', null, 'EgyptAir', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SSH', 'Pearl Assist', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('NKC', 'Ya Marhaba', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: Kalkıştan 4 saat öncesi. Giriş penceresi: kalkıştan 4 saat önce', true),
  ('UBN', 'Blue Sky Lounge', 'Dış Hatlar Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat. Yeni Chinggis Khaan havalimanı; eski havalimanı kodu ULN idi', true),
  ('MPM', 'Fnb by Pearl Assist', 'A Terminali', null, null, 'both', 'Hizmet saatleri: 4:30''dan son uçuşa kadar', true),
  ('KTM', 'Radisson Service', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 05.00-03.00', true),
  ('KTM', 'Horizon Service', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 05.00-03.00', true),
  ('NIM', 'Salon CIP', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('ABV', 'Lounge Sds', 'International Terminal', null, null, 'both', 'Hizmet saatleri: 04:00-24:00', true),
  ('LOS', 'Sappire Lounge', '2. Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş saatleri', true),
  ('OSL', 'OSL Lounge', 'Dış Hatlar Gidiş Terminali 2. Kat', null, null, 'both', 'Hizmet saatleri: 05:15 - 20:30', true),
  ('TAS', 'Anjir Business Lounge', 'Terminal 2', null, null, 'both', 'Hizmet saatleri: Uçuş saatleri', true),
  ('ISB', 'Airlines', 'Uluslararası Gidiş Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('KHI', 'Caa CIP', 'Uluslararası Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('LHE', 'Salon CIP', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('PTY', 'Copa', 'Terminal 1 / 2', null, 'Copa Airlines', 'both', 'Hizmet saatleri: 05:30 – 21:30 (T1); 05:30 – 21:00 (T2)', true),
  ('OPO', 'Lounge Ana', '1. Terminali', null, 'ANA Aeroportos', 'both', 'Hizmet saatleri: 04:00 - 23:00', true),
  ('LIS', 'ANA Aeroportos Lounge', '1. Terminali', null, 'ANA Aeroportos', 'both', 'Hizmet saatleri: Uçuş zamanlarında', true),
  ('WAW', 'Bolero', 'Schengen Olmayan Bölge', null, null, 'both', 'Hizmet saatleri: 6:30-22:00', true),
  ('WAW', 'Mazurek (Star Alliance Lounge)', 'Schengen Olmayan Bölge', null, 'Star Alliance', 'both', 'Hizmet saatleri: 06:00-22:00', true),
  ('WAW', 'PPL', 'Schengen Olmayan Bölge', null, null, 'both', 'Hizmet saatleri: Uçuş saatleri', true),
  ('KRK', 'Balice International Airport', 'Terminal 1', null, null, 'both', 'Hizmet saatleri: Uçuş Saatleri', true),
  ('OTP', 'Satellite Business', 'Uluslararası Gidiş Terminali (9. Kapı Üstü)', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('OTP', 'Tarom Business', 'Uluslararası Gidiş Terminali (3. Kapı Üstü)', null, 'Tarom', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('CLJ', 'Protocol Business Lounge', 'Uluslararası Terminali', null, null, 'both', 'Hizmet saatleri: 05:00 - 19:00', true),
  ('TSR', 'S.N. Aeroportul International Timisoara', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: Uçuş saatleri', true),
  ('KGL', 'Pearl', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('KZN', 'SKY Lounge', '1A Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('VKO', 'Istanbul-Moscow', 'Terminal A', null, 'Turkish Airlines', 'both', 'Hizmet saatleri: 7 gün 24 saat. THY''nin kendi salonu; yurtdışı listesinde de var', true),
  ('LED', 'Business Lounge (International)', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('DSS', 'Odyssee - Infinite - Topkapi', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SEZ', 'Air Seychelles (Salon Vallee De Mai)', 'Ana terminal', null, 'Air Seychelles', 'both', 'Hizmet saatleri: Uçuş saatleri', true),
  ('BEG', 'Air Serbia Premium Lounge', '1. Terminal', null, 'Air Serbia', 'both', 'Hizmet saatleri: 5:00 - 18:00', true),
  ('FNA', 'Mcleod Airport Lounge', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SIN', 'Sats Premium Lounge', '1. Terminal', null, 'SATS', 'both', 'Hizmet saatleri: 06:00 - 01:00', true),
  ('LJU', 'Business', 'Uluslararası Gidiş Terminali', null, null, 'both', 'Hizmet saatleri: 5:00 - 23:00', true),
  ('CMB', 'Araliya', 'Ana Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('KRT', 'Sas CIP', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('DMM', 'Plaza Premium', 'Single Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('MED', 'PrimeClass Lounge', 'Dış Hatlar Terminali', null, 'Primeclass', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('RUH', 'Cozaya Lounge', 'Terminal 5', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('TIF', 'Hayyak Lounge', 'Dış Hatlar Terminali', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SCL', 'Primeclass Santiago SPA', '1. Terminal', null, 'Primeclass', 'both', 'Hizmet saatleri: Uçuş zamanlarında', true),
  ('DAR', 'Twiga Lounge', '3. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('JRO', 'Twiga by Aspire', 'Ana Terminal', null, 'Aspire', 'both', 'Hizmet saatleri: 24 saat (Pzt, Çar, Cum, Paz); 5:00-22:00 (Sal, Per, Cmt)', true),
  ('ZNZ', 'Marhaba Lounge', '3. Terminal', null, 'Marhaba', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('BKK', 'Turkish Airlines', 'Uluslararası Terminal', null, 'Turkish Airlines', 'both', 'Hizmet saatleri: 7 gün 24 saat. THY''nin kendi salonu; yurtdışı listesinde de var', true),
  ('HKT', 'The Coral Executive Loounge', 'Ana Terminal Binası 4. kat', null, null, 'both', 'Hizmet saatleri: 06:00 - 00:00', true),
  ('TPE', 'Plaza Premium', '2. Terminal', null, 'Plaza Premium', 'both', 'Hizmet saatleri: 5:00 - 23:00', true),
  ('TUN', 'Salon Privilige', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('EBB', 'Karibu', '1. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('MCT', 'Primeclass', 'Ana Terminal', null, 'Primeclass', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('AMM', 'Crown', '1. Terminal', null, 'Royal Jordanian', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('AQJ', 'Aqaba Lounge', '1. Terminal', null, null, 'both', 'Hizmet saatleri: Pazartesi 22:05-01:05; Çarşamba 23:55-02:55; Cuma 22:05-01:05. Sadece 3 gün açık — çok dar pencere', true),
  ('CCS', 'Aero VIP', 'Uluslararası Gidiş Terminali', null, null, 'both', 'Hizmet saatleri: Uçuş zamanları', true),
  ('HAN', 'Nia Lounge', '2. Terminal', null, null, 'both', 'Hizmet saatleri: 06:00 - 24:00', true),
  ('SGN', 'Le Saigonnais Business', '2. Terminal', null, null, 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('ATH', 'Goldair Handling', 'A Terminali', null, 'Goldair Handling', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('SKG', 'Aegean', '2. Terminal', null, 'Aegean Airlines', 'both', 'Hizmet saatleri: 7 gün 24 saat', true),
  ('LUN', 'Pearl Lounge', '3. Terminali', null, null, 'both', 'Hizmet saatleri: Uçuş zamanlarında', true)
on conflict (airport_code, name, coalesce(section, '')) do update set
  terminal = coalesce(nullif(excluded.terminal, ''), lounge_venues.terminal),
  operator = coalesce(excluded.operator, lounge_venues.operator),
  scope    = coalesce(excluded.scope, lounge_venues.scope),
  notes    = coalesce(nullif(excluded.notes, ''), lounge_venues.notes),
  active   = true;

-- ---- 3) KATALOG (lounges) — app'in salon seciciyi besledigi tablo ----
-- 🔴 158/160/161 katalogu venue basina TEK aktif kayda indirmisti.
-- Yeni venue'lar icin karsilik uretilmezse host salonu SECEMEZ —
-- "lounge listeleri bos geliyor" sikayetinin ikinci yarisi tam bu.
insert into lounges (airport_code, name, terminal, access_types, venue_id, active)
select v.airport_code::char(3), v.name, v.terminal, '{}'::text[], v.id, true
  from lounge_venues v
 where v.active
   and not exists (select 1 from lounges l where l.venue_id = v.id and l.active);

-- ---- 4) KABUL SATIRLARI — bu salonlar THY'nin KENDI listesinde ----
-- Bir salon THY'nin yurtici/yurtdisi/anlasmali listesindeyse, THY
-- Miles&Smiles statusuyle oraya girilebiliyor demektir. Kaynak bu.
-- 🔴 Misafir politikasi BURADA belirlenmez; kural motoru (156/172/174)
-- belirler. Kabul satiri yalnizca "bu program bu salona giriyor" der.
-- 'unknown' yazmak, bilmedigimizi soylemenin dogru yoludur —
-- 'included' yazmak host'a olmayan bir hak vaat ederdi.
insert into lounge_venue_acceptance
  (venue_id, program_id, accepted, guest_policy, is_placeholder, source_url, active)
select v.id, p.id, true, 'unknown', true,
       'https://www.turkishairlines.com/tr-tr/ucak-bileti/ucus-deneyimi/', true
  from lounge_venues v
  cross join lounge_programs p
 where v.active and p.code = 'TK_MS'
   and not exists (select 1 from lounge_venue_acceptance a
                    where a.venue_id = v.id and a.program_id = p.id)
   -- 188 ile gelen salonlar: notes ya da kaynak listesinden
   and v.created_at >= now() - interval '1 hour';

-- ---- 5) BEKÇİLER ----
do $$
declare v_ap int; v_ven int; v_kat int; v_bos int;
begin
  select count(distinct airport_code) into v_ap from lounge_venues where active;
  select count(*) into v_ven from lounge_venues where active;
  select count(*) into v_kat from lounges where active;

  -- Her aktif salonun katalog karsiligi olmali (host secebilsin).
  select count(*) into v_bos from lounge_venues v
   where v.active and not exists (select 1 from lounges l
                                   where l.venue_id = v.id and l.active);
  if v_bos > 0 then
    raise exception '188: % aktif salonun katalog karsiligi yok — host secemez', v_bos;
  end if;

  raise notice '188: % havalimani · % salon · % katalog kaydi', v_ap, v_ven, v_kat;
end $$;

-- BEKÇİ: Türkiye kapsami. Kaynak listede 12 TR havalimani var;
-- ürünün ANA PAZARI burasi, eksik kalirsa migration DURUR.
do $$
declare v_n int; v_eksik text;
begin
  select count(distinct v.airport_code) into v_n
    from lounge_venues v join airports a on a.code = v.airport_code
   where v.active and a.country in ('Türkiye', 'Turkiye', 'TR', 'Turkey');
  if v_n < 12 then
    select string_agg(x, ', ') into v_eksik from (
      select unnest(array['IST','SAW','ESB','ADB','AYT','BJV','GZT','HTY','ASR','TZX','RZV','COV']) x
      except select airport_code from lounge_venues where active
    ) s;
    raise exception '188: TR kapsami eksik (% havalimani). Eksik: %', v_n, coalesce(v_eksik, '?');
  end if;
  raise notice '188: TR kapsami tam — % havalimani', v_n;
end $$;

-- BEKÇİ: lounges_for_airport her TR havalimaninda satir dondurmeli.
-- 🔴 Bir onceki turda "salon listeleri bos" tam olarak burada kirildi
-- ve hicbir denetim gormedi: fonksiyon VARDI, satir DONDURMUYORDU.
do $$
declare r record; v_n int; v_bos int := 0;
begin
  for r in
    select distinct v.airport_code ap from lounge_venues v
      join airports a on a.code = v.airport_code
     where v.active and a.country in ('Türkiye','Turkiye','TR','Turkey')
  loop
    select count(*) into v_n from public.lounges_for_airport(r.ap);
    if v_n = 0 then
      raise warning '188: % icin salon listesi BOS', r.ap;
      v_bos := v_bos + 1;
    end if;
  end loop;
  if v_bos > 0 then
    raise exception '188: % TR havalimaninda salon listesi bos donuyor', v_bos;
  end if;
  raise notice '188: her TR havalimani salon donduruyor';
end $$;

select '188 OK - salon envanteri yuklendi' as sonuc;
