/*
  ANALİZ: Takım Performans Dashboard (Detaylı)
  AMACI: İç saha, deplasman galibiyetleri, toplam maç sayısı ve genel galibiyet oranını görmek.
*/

SELECT 
    takim_adi,
    SUM(ev_sahibi_galibiyet) AS ic_saha_galibiyet,
    SUM(deplasman_galibiyet) AS deplasman_galibiyet,
    SUM(ev_sahibi_galibiyet + deplasman_galibiyet) AS toplam_galibiyet,
    COUNT(*) AS toplam_mac_sayisi, -- İşte burası toplam maç sayını veriyor
    ROUND(100.0 * SUM(ev_sahibi_galibiyet + deplasman_galibiyet) / COUNT(*), 2) AS galibiyet_orani_yuzde
FROM (
    SELECT 
        home_team AS takim_adi,
        CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END AS ev_sahibi_galibiyet,
        0 AS deplasman_galibiyet
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    
    UNION ALL
    
    SELECT 
        away_team AS takim_adi,
        0 AS ev_sahibi_galibiyet,
        CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END AS deplasman_galibiyet
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
)
GROUP BY takim_adi
ORDER BY toplam_galibiyet DESC;





/*
  ANALİZ: Takım Performans Dashboard (Maç Başı Puan - PPG)
  AMACI: Takımların toplam puan performansını ve maç başına düşen puan verimliliğini görmek.
*/

SELECT 
    takim_adi,
    SUM(toplam_galibiyet) AS toplam_galibiyet,
    SUM(toplam_beraberlik) AS toplam_beraberlik,
    SUM(toplam_maglubiyet) AS toplam_maglubiyet,
    COUNT(*) AS toplam_mac_sayisi,
    SUM(puan) AS toplam_puan,
    -- Maç başına alınan puan (PPG)
    ROUND(SUM(puan) / COUNT(*), 2) AS mac_basi_puan
FROM (
    -- Ev sahibi performansları
    SELECT 
        home_team AS takim_adi,
        CASE WHEN match_result = 'Home Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan,
        CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END AS toplam_galibiyet,
        CASE WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS toplam_beraberlik,
        CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END AS toplam_maglubiyet
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    
    UNION ALL
    
    -- Deplasman performansları
    SELECT 
        away_team AS takim_adi,
        CASE WHEN match_result = 'Away Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan,
        CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END AS toplam_galibiyet,
        CASE WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS toplam_beraberlik,
        CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END AS toplam_maglubiyet
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
)
GROUP BY takim_adi
ORDER BY mac_basi_puan DESC;






/*
  ANALİZ: Sezon Bazlı Şampiyonluk Yarışları
  AMACI: Her sezon ve lig için en çok puan toplayan (şampiyon) takımları listelemek.
*/

WITH sezonluk_puanlar AS (
    -- Her takımın her sezondaki toplam puanını hesaplıyoruz
    SELECT 
        season,
        league_name,
        takim_adi,
        SUM(puan) AS toplam_puan
    FROM (
        SELECT season, league_name, home_team AS takim_adi, 
               CASE WHEN match_result = 'Home Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
        UNION ALL
        SELECT season, league_name, away_team AS takim_adi, 
               CASE WHEN match_result = 'Away Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    )
    GROUP BY 1, 2, 3
),
siralama AS (
    -- Her lig ve sezonda takımlara puanlarına göre sıra veriyoruz
    SELECT 
        season,
        league_name,
        takim_adi,
        toplam_puan,
        RANK() OVER(PARTITION BY season, league_name ORDER BY toplam_puan DESC) as sira
    FROM sezonluk_puanlar
)
SELECT 
    season AS sezon,
    league_name AS lig,
    takim_adi AS sampiyon,
    toplam_puan AS sampiyon_puani
FROM siralama
WHERE sira = 1
ORDER BY sezon DESC, lig ASC;





/*
  ANALİZ: Ev Sahibi Avantajı (Win Rate)
  AMACI: Lig bazında ev sahibi takımların kazanma oranlarını hesaplayarak,
         iç saha avantajının hangi liglerde daha yüksek olduğunu belirlemek.
*/

SELECT 
    league_name,
    COUNT(*) AS toplam_mac_sayisi,
    SUM(CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END) AS ev_sahibi_galibiyet_sayisi,
    ROUND(100.0 * SUM(CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END) / COUNT(*), 2) AS ev_sahibi_galibiyet_orani_yuzde
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY 1
ORDER BY ev_sahibi_galibiyet_orani_yuzde DESC;








/*
  ANALİZ: Gol Verimliliği (İç Saha vs. Deplasman)
  AMACI: Hangi ligde ev sahibi ve deplasman takımlarının maç başına 
         kaç gol ortalamasıyla oynadığını karşılaştırmak.
*/

SELECT 
    league_name,
    ROUND(AVG(home_team_goal), 2) AS ev_sahibi_gol_ortalamasi,
    ROUND(AVG(away_team_goal), 2) AS deplasman_gol_ortalamasi,
    -- Toplam gol ortalaması
    ROUND(AVG(home_team_goal + away_team_goal), 2) AS genel_gol_ortalamasi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY 1
ORDER BY genel_gol_ortalamasi DESC;





/*
  ANALİZ: Lig Bazlı İç Saha Avantajı (Home Field Advantage)
  AMACI: Hangi liglerde ev sahibi olmanın istatistiksel olarak daha büyük bir 
         galibiyet şansı sağladığını belirlemek.
*/

SELECT 
    league_name,
    COUNT(*) AS toplam_mac_sayisi,
    ROUND(100.0 * SUM(CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END) / COUNT(*), 2) AS ev_sahibi_kazanma_orani_yuzde,
    ROUND(100.0 * SUM(CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END) / COUNT(*), 2) AS deplasman_kazanma_orani_yuzde,
    ROUND(100.0 * SUM(CASE WHEN match_result = 'Draw' THEN 1 ELSE 0 END) / COUNT(*), 2) AS beraberlik_orani_yuzde
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY league_name
ORDER BY ev_sahibi_kazanma_orani_yuzde DESC;








/*
  ANALİZ: En Çok Gol Atan Takımlar
  AMACI: Takımların ligdeki toplam ofansif gücünü ve hücum performansını belirlemek.
*/

SELECT 
    takim_adi,
    SUM(atilan_gol) AS toplam_atilan_gol,
    SUM(yenilen_gol) AS toplam_yenilen_gol,
    SUM(atilan_gol - yenilen_gol) AS averaj,
    COUNT(*) AS toplam_mac_sayisi,
    ROUND(SUM(atilan_gol) * 1.0 / COUNT(*), 2) AS mac_basi_gol_ortalamasi
FROM (
    -- Ev sahibi golleri
    SELECT 
        home_team AS takim_adi, 
        home_team_goal AS atilan_gol, 
        away_team_goal AS yenilen_gol
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    
    UNION ALL
    
    -- Deplasman golleri
    SELECT 
        away_team AS takim_adi, 
        away_team_goal AS atilan_gol, 
        home_team_goal AS yenilen_gol
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
)
GROUP BY takim_adi
ORDER BY toplam_atilan_gol DESC;







/*
  ANALİZ: En İyi Savunma Performansı (Maç Başı Yenen Gol Ortalaması)
  AMACI: Takımların savunma disiplinini, maç başına yenen gol ortalamasına göre 
         en sağlamdan başlayarak sıralamak.
*/

SELECT 
    takim_adi,
    SUM(yenilen_gol) AS toplam_yenilen_gol,
    COUNT(*) AS toplam_mac_sayisi,
    -- Maç başına yenilen gol (Sıralama bu sütun üzerinden yapılacak)
    ROUND(SUM(yenilen_gol) * 1.0 / COUNT(*), 3) AS mac_basi_yenen_gol_ortalamasi
FROM (
    SELECT home_team AS takim_adi, away_team_goal AS yenilen_gol
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    UNION ALL
    SELECT away_team AS takim_adi, home_team_goal AS yenilen_gol
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
)
GROUP BY takim_adi
HAVING toplam_mac_sayisi > 5 -- Çok az maç yapan takımları eleyerek istatistiği anlamlı kılıyoruz
ORDER BY mac_basi_yenen_gol_ortalamasi ASC;






/*
  ANALİZ: Gol Averajı ve Verimlilik Analizi
  AMACI: Takımların hücum ve savunma dengesini 'Averaj' ve 
         'Maç Başı Averaj' üzerinden görmek.
*/

SELECT 
    takim_adi,
    SUM(atilan_gol) AS toplam_atilan_gol,
    SUM(yenilen_gol) AS toplam_yenilen_gol,
    (SUM(atilan_gol) - SUM(yenilen_gol)) AS gol_averaji,
    COUNT(*) AS toplam_mac_sayisi,
    ROUND((SUM(atilan_gol) - SUM(yenilen_gol)) * 1.0 / COUNT(*), 3) AS mac_basi_averaj
FROM (
    -- Ev sahibi performansı
    SELECT home_team AS takim_adi, home_team_goal AS atilan_gol, away_team_goal AS yenilen_gol
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    UNION ALL
    -- Deplasman performansı
    SELECT away_team AS takim_adi, away_team_goal AS atilan_gol, home_team_goal AS yenilen_gol
    FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
)
GROUP BY takim_adi
HAVING toplam_mac_sayisi > 5
ORDER BY gol_averaji DESC;





-- İSTİKRAR ANALİZİ --


/*
  ANALİZ: Takım Performans Trendi ve İstikrar Analizi
  AMACI: Takımların yıllar içindeki maç başı puan (PPG) değişimini ve 
         istikrar trendini (yükseliş/düşüş) analiz etmek.
*/

WITH sezonluk_performans AS (
    -- Önce her takımın sezonluk maç başı puanını hesaplayalım
    SELECT 
        season,
        takim_adi,
        SUM(puan) * 1.0 / COUNT(*) AS ppg,
        COUNT(*) AS mac_sayisi
    FROM (
        SELECT season, home_team AS takim_adi, 
               CASE WHEN match_result = 'Home Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
        UNION ALL
        SELECT season, away_team AS takim_adi, 
               CASE WHEN match_result = 'Away Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    )
    GROUP BY 1, 2
    HAVING mac_sayisi > 5
),
trend_analizi AS (
    -- Bir önceki sezonun performansını yanına getirerek değişimi hesaplayalım
    SELECT 
        season,
        takim_adi,
        ppg,
        LAG(ppg) OVER(PARTITION BY takim_adi ORDER BY season) AS onceki_sezon_ppg
    FROM sezonluk_performans
)
SELECT 
    season AS sezon,
    takim_adi,
    ROUND(ppg, 2) AS guncel_ppg,
    ROUND(onceki_sezon_ppg, 2) AS eski_ppg,
    ROUND(ppg - onceki_sezon_ppg, 2) AS performans_degisimi,
    CASE 
        WHEN (ppg - onceki_sezon_ppg) > 0.1 THEN 'Yükseliş'
        WHEN (ppg - onceki_sezon_ppg) < -0.1 THEN 'Düşüş'
        ELSE 'İstikrarlı'
    END AS trend
FROM trend_analizi
WHERE onceki_sezon_ppg IS NOT NULL
ORDER BY sezon DESC, performans_degisimi DESC;





-- LİG KARŞILAŞTIRMALARI / LİGLERİN GOL PROFİLLERİ --

/*
  ANALİZ: Lig Bazlı Maç Başına Gol Ortalaması
  AMACI: Liglerin hücum verimliliğini karşılaştırarak "en golcü" ligleri tespit etmek.
*/

SELECT 
    league_name,
    COUNT(*) AS oynanan_mac_sayisi,
    SUM(home_team_goal + away_team_goal) AS toplam_gol_sayisi,
    ROUND(SUM(home_team_goal + away_team_goal) * 1.0 / COUNT(*), 2) AS mac_basi_gol_ortalamasi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY league_name
ORDER BY mac_basi_gol_ortalamasi DESC;




/*
  ANALİZ: En Hücumcu Ligler
  AMACI: Ligleri maç başına düşen gol sayısına göre azalan sırada dizerek 
         en çok gol izlenen (hücumcu) ligleri belirlemek.
*/

SELECT 
    league_name,
    COUNT(*) AS mac_sayisi,
    ROUND(SUM(home_team_goal + away_team_goal) * 1.0 / COUNT(*), 3) AS mac_basi_gol_ortalamasi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY league_name
HAVING mac_sayisi > 20 -- Veri anlamlılığı için minimum maç sayısı filtresi
ORDER BY mac_basi_gol_ortalamasi DESC;





/*
  ANALİZ: En Savunmacı Ligler
  AMACI: Maç başına en az gol ortalamasına sahip ligleri bularak, 
         savunma disiplininin veya kontrollü oyunun baskın olduğu ligleri belirlemek.
*/

SELECT 
    league_name,
    COUNT(*) AS mac_sayisi,
    ROUND(SUM(home_team_goal + away_team_goal) * 1.0 / COUNT(*), 3) AS mac_basi_gol_ortalamasi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY league_name
HAVING mac_sayisi > 20
ORDER BY mac_basi_gol_ortalamasi ASC; -- ASC ile en az gol olanı en üste aldık




-- REKABET SEVİYESİ --

/*
  ANALİZ: Puan Dağılımı ve Lig Rekabeti
  AMACI: Takımların topladıkları toplam puanları lig bazında kategorize ederek 
         rekabet yoğunluğunu ve puan farklarını ölçmek.
*/

SELECT 
    league_name,
    COUNT(takim_adi) AS takim_sayisi,
    ROUND(AVG(toplam_puan), 2) AS lig_ortalama_puan,
    MAX(toplam_puan) AS ligin_en_yuksek_puani,
    MIN(toplam_puan) AS ligin_en_dusuk_puani,
    (MAX(toplam_puan) - MIN(toplam_puan)) AS puan_makasi
FROM (
    -- Her takımın sezonluk toplam puanını hesaplıyoruz
    SELECT 
        league_name,
        takim_adi,
        SUM(puan) AS toplam_puan
    FROM (
        SELECT league_name, home_team AS takim_adi, 
               CASE WHEN match_result = 'Home Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
        UNION ALL
        SELECT league_name, away_team AS takim_adi, 
               CASE WHEN match_result = 'Away Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    )
    GROUP BY league_name, takim_adi
)
GROUP BY league_name
ORDER BY puan_makasi ASC; -- En dengeli (puan makası düşük) ligi en başa alır








/*
  ANALİZ: Şampiyonluk Yarışının Yakınlığı
  AMACI: Şampiyon olan takım ile lig ikincisi arasındaki puan farkını bularak,
         yarışın rekabet düzeyini ölçmek.
*/

WITH lig_sonu_puan_durumu AS (
    -- Her takımın sezonluk toplam puanını hesapla
    SELECT 
        season,
        league_name,
        takim_adi,
        SUM(puan) AS toplam_puan
    FROM (
        SELECT season, league_name, home_team AS takim_adi, 
               CASE WHEN match_result = 'Home Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
        UNION ALL
        SELECT season, league_name, away_team AS takim_adi, 
               CASE WHEN match_result = 'Away Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END AS puan
        FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
    )
    GROUP BY 1, 2, 3
),
siralama AS (
    -- Her lig ve sezonda takımları puanlarına göre sırala
    SELECT 
        season,
        league_name,
        takim_adi,
        toplam_puan,
        DENSE_RANK() OVER(PARTITION BY season, league_name ORDER BY toplam_puan DESC) as sira
    FROM lig_sonu_puan_durumu
)
SELECT 
    season,
    league_name,
    MAX(CASE WHEN sira = 1 THEN toplam_puan END) AS sampiyon_puani,
    MAX(CASE WHEN sira = 2 THEN toplam_puan END) AS ikinci_puani,
    (MAX(CASE WHEN sira = 1 THEN toplam_puan END) - MAX(CASE WHEN sira = 2 THEN toplam_puan END)) AS puan_farki
FROM siralama
GROUP BY 1, 2
HAVING ikinci_puani IS NOT NULL
ORDER BY puan_farki ASC;




-- ÜLKELER ARASI KARŞILAŞTIRMALAR --

SELECT 
    league_name,
    ROUND(AVG(home_team_goal + away_team_goal), 2) AS mac_basi_toplam_gol,
    ROUND(AVG(home_team_goal - away_team_goal), 3) AS lig_net_averaj_egilimi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
WHERE league_name IN ('England Premier League', 'Spain LIGA BBVA', 'Germany 1. Bundesliga', 'Italy Serie A', 'Portugal Liga ZON Sagres')
GROUP BY league_name
ORDER BY mac_basi_toplam_gol DESC;



-- Liglerin ev sahibi avantajı farklılıkları --

SELECT 
    league_name,
    COUNT(*) AS toplam_mac,
    ROUND(SUM(CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS evinde_kazanma_yuzdesi,
    ROUND(SUM(CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS deplasmanda_kazanma_yuzdesi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
WHERE league_name IN ('England Premier League', 'Spain LIGA BBVA', 'Germany 1. Bundesliga', 'Italy Serie A', 'Portugal Liga ZON Sagres')
GROUP BY league_name
ORDER BY evinde_kazanma_yuzdesi DESC;




-- OYUNCU PERFORMANS ANALİZİ --

/*
  ANALİZ: En Yüksek Overall Rating'e Sahip Oyuncular
  AMACI: Oyuncuları kariyerleri boyunca ulaştıkları en yüksek reytinge (overall_rating) göre sıralamak.
*/

SELECT 
    p.player_name,
    DATE(p.birthday) as dogum_tarihi,
    MAX(n.overall_rating) AS en_yuksek_reyting,
    COUNT(n.overall_rating) AS veri_noktasi_sayisi
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY p.player_name, p.birthday
ORDER BY en_yuksek_reyting DESC
LIMIT 20;




/*
  ANALİZ: En Yüksek Potansiyele Sahip Oyuncular
  AMACI: Oyuncuları potansiyel reytinglerine göre sıralamak ve 
         mevcut reyting ile aralarındaki farkı (gelişim marjı) hesaplamak.
*/

SELECT 
    p.player_name,
    DATE(p.birthday) AS dogum_tarihi,
    MAX(n.overall_rating) AS mevcut_max_reyting,
    MAX(n.potential) AS potansiyel_reyting,
    (MAX(n.potential) - MAX(n.overall_rating)) AS gelisim_marji -- Aradaki fark
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY p.player_name, p.birthday
HAVING potansiyel_reyting > 85 -- Sadece üst düzey potansiyellileri getiriyoruz
ORDER BY potansiyel_reyting DESC
LIMIT 20;





-- YAŞ VE PERFORMANS İLİŞKİSİ --

/*
  ANALİZ: Yaşa Göre Performans Değişimi
  AMACI: Oyuncuların yaşına göre (Overall Rating) ortalama performansını belirlemek.
*/

SELECT 
    EXTRACT(YEAR FROM n.rating_date) - EXTRACT(YEAR FROM p.birthday) AS yas,
    ROUND(AVG(n.overall_rating), 2) AS ortalama_performans,
    COUNT(p.player_api_id) AS oyuncu_gozlem_sayisi
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY yas
HAVING yas BETWEEN 16 AND 40 -- Futbolcu yaş aralığı
ORDER BY yas ASC;

-- Zirve performans yaşı kaç?--

SELECT 
    EXTRACT(YEAR FROM n.rating_date) - EXTRACT(YEAR FROM p.birthday) AS yas,
    ROUND(AVG(n.overall_rating), 2) AS ortalama_performans,
    COUNT(p.player_api_id) AS oyuncu_gozlem_sayisi
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY yas
HAVING yas BETWEEN 16 AND 40
ORDER BY ortalama_performans DESC;



-- Fiziksel özellik analizi --

/*
  ANALİZ: Boy ve Performans İlişkisi
  AMACI: Oyuncuların boylarının, genel performans reytingleri üzerindeki etkisini incelemek.
*/

SELECT 
    -- Boyu 5'er cm'lik aralıklarla gruplandırıyoruz
    FLOOR(p.height / 5) * 5 AS boy_araligi, 
    ROUND(AVG(n.overall_rating), 2) AS ortalama_performans,
    COUNT(p.player_api_id) AS oyuncu_sayisi
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY boy_araligi
HAVING boy_araligi IS NOT NULL
ORDER BY boy_araligi ASC;




/*
  ANALİZ: Kilo (kg) ve Performans İlişkisi
  AMACI: Oyuncuların lbs olan ağırlığını kg'a çevirerek gerçekçi bir analiz yapmak.
*/

SELECT 
    -- Lbs değerini kg'a çevirip 5'er kg'lık gruplara ayırıyoruz
    FLOOR((p.weight / 2.20462) / 5) * 5 AS kilo_araligi_kg,
    ROUND(AVG(n.overall_rating), 2) AS ortalama_performans,
    COUNT(p.player_api_id) AS oyuncu_sayisi
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY kilo_araligi_kg
HAVING kilo_araligi_kg IS NOT NULL
ORDER BY kilo_araligi_kg ASC;



/*
  ANALİZ: Yaş ve Performans İlişkisi
  AMACI: Oyuncuların yaşına göre ortalama performansını belirlemek.
*/

SELECT 
    EXTRACT(YEAR FROM n.rating_date) - EXTRACT(YEAR FROM p.birthday) AS yas,
    ROUND(AVG(n.overall_rating), 1) AS ortalama_performans,
    COUNT(p.player_api_id) AS gozlem_sayisi
FROM `fatihdata.european_soccer_analysis.Player` AS p
JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS n
  ON p.player_api_id = n.player_api_id
GROUP BY yas
HAVING yas BETWEEN 18 AND 40
ORDER BY yas ASC;



