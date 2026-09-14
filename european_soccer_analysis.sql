-- Ev sahibi takım performansı analizi
/*
  AMACI: Takımların kendi sahalarındaki başarılarını; toplam maç sayıları, 
         net galibiyet/beraberlik/mağlubiyet sayıları ve yüzdesel oranları 
         üzerinden hesaplar.
  
  KULLANILAN MANTIKSAL ADIMLAR:
  1. CASE WHEN: Maç sonuçları (gol sayılarına göre) 3 kategoriye ayrıldı.
  2. ROUND & COUNT: Yüzdeler hesaplanırken virgülden sonra 2 basamak istendi.
  3. HAVING: İstatistiksel anlamlılık için 20'den az maçı olan takımlar filtrelendi.
*/
SELECT 
    home_team AS team_name,
    COUNT(*) AS total_home_matches,
    -- Net Sayılar
    SUM(CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END) AS home_wins,
    SUM(CASE WHEN match_result = 'Draw' THEN 1 ELSE 0 END) AS home_draws,
    SUM(CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END) AS home_losses,
    -- Oranlar (Yüzde olarak)
    ROUND(AVG(CASE WHEN match_result = 'Home Win' THEN 1.0 ELSE 0.0 END) * 100, 2) AS win_rate,
    ROUND(AVG(CASE WHEN match_result = 'Draw' THEN 1.0 ELSE 0.0 END) * 100, 2) AS draw_rate,
    ROUND(AVG(CASE WHEN match_result = 'Away Win' THEN 1.0 ELSE 0.0 END) * 100, 2) AS loss_rate
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY home_team
HAVING COUNT(*) > 20
ORDER BY win_rate DESC;



/*
  Deplasman başarısı analizi
/*
  ANALİZ: Deplasman Dayanıklılığı (Mart Tablosu ile)
  AMACI: Takımların 'Deplasman Dayanıklılığını' kıyaslayarak saha bağımlılıklarını analiz eder.
*/

SELECT 
    away_team AS team_name,
    COUNT(*) AS total_away_matches,
    -- Net Sayılar
    SUM(CASE WHEN match_result = 'Away Win' THEN 1 ELSE 0 END) AS away_wins,
    SUM(CASE WHEN match_result = 'Draw' THEN 1 ELSE 0 END) AS away_draws,
    SUM(CASE WHEN match_result = 'Home Win' THEN 1 ELSE 0 END) AS away_losses,
    -- Yüzdeler
    ROUND(AVG(CASE WHEN match_result = 'Away Win' THEN 1.0 ELSE 0.0 END) * 100, 2) AS away_win_rate,
    ROUND(AVG(CASE WHEN match_result = 'Draw' THEN 1.0 ELSE 0.0 END) * 100, 2) AS away_draw_rate,
    ROUND(AVG(CASE WHEN match_result = 'Home Win' THEN 1.0 ELSE 0.0 END) * 100, 2) AS away_loss_rate
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY away_team
HAVING COUNT(*) > 20
ORDER BY away_win_rate DESC;



/*
  ANALİZ: Avrupa Futbolunda Yenilmezlik Serileri
  AMACI: Takımların mağlup olmadan tamamladıkları en uzun serileri (20+ maç) bulmak.
  NOT: 'mart_lig_ve_takim_performans' tablosu sayesinde JOIN işlemine gerek kalmadan, 
       her takımın tüm maçlarını tek bir akışta işliyoruz.
*/

WITH MatchOutcomes AS (
  -- Takımların tüm maçlarını (ev sahibi veya deplasman fark etmeksizin) tek bir listeye alıyoruz
  SELECT 
    home_team AS team_name,
    date,
    CASE WHEN match_result IN ('Home Win', 'Draw') THEN 1 ELSE 0 END AS is_undefeated
  FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
  UNION ALL
  SELECT 
    away_team,
    date,
    CASE WHEN match_result IN ('Away Win', 'Draw') THEN 1 ELSE 0 END AS is_undefeated
  FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
),
GroupedMatches AS (
  SELECT *,
    -- Seri tanımlama: Yenilmezlik durumu 1 iken bir önceki durum 0 ise yeni bir seri (ada) başlar
    SUM(CASE WHEN is_undefeated = 1 AND prev_status = 0 THEN 1 ELSE 0 END) 
      OVER (PARTITION BY team_name ORDER BY date) as series_id
  FROM (
    SELECT *,
      LAG(is_undefeated, 1, 0) OVER (PARTITION BY team_name ORDER BY date) as prev_status
    FROM MatchOutcomes
  )
)
SELECT 
  team_name,
  COUNT(*) as streak_length,
  MIN(date) as start_date,
  MAX(date) as end_date
FROM GroupedMatches
WHERE is_undefeated = 1
GROUP BY team_name, series_id
HAVING streak_length > 20 
ORDER BY streak_length DESC;



/*
  ANALİZ: Bahis Tahminleri ve Gerçekleşen Sonuçların Analizi
  AMACI: Bahis şirketlerinin favori ilan ettiği sonuçların isabet oranını ölçmek.
*/

WITH Predictions AS (
  SELECT 
    -- En düşük oranı bulup favoriyi belirle
    CASE 
      WHEN bet_home_odds <= bet_draw_odds AND bet_home_odds <= bet_away_odds THEN 'Home'
      WHEN bet_draw_odds <= bet_home_odds AND bet_draw_odds <= bet_away_odds THEN 'Draw'
      ELSE 'Away'
    END AS favorite,
    -- Gerçek sonucu zaten temizlenmiş sütundan alıyoruz
    CASE 
      WHEN match_result = 'Home Win' THEN 'Home'
      WHEN match_result = 'Draw' THEN 'Draw'
      ELSE 'Away'
    END AS actual_result
  FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
  WHERE bet_home_odds IS NOT NULL
)
SELECT 
  favorite,
  COUNT(*) AS total_prediction_count,
  SUM(CASE WHEN favorite = actual_result THEN 1 ELSE 0 END) AS correct_count,
  ROUND(SUM(CASE WHEN favorite = actual_result THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS accuracy_rate
FROM Predictions
GROUP BY favorite
ORDER BY accuracy_rate DESC;


-- LİGLERİN REKABETİ -- 

/*
  ANALİZ: Liglerin Rekabetçi Denge İndeksi
  AMACI: Ligin rekabetçi olup olmadığını, zirve ile dip arasındaki puan farkından (point_gap) ölçmek.
*/

WITH CombinedPoints AS (
  -- Ev sahibi maçlarından gelen puanlar
  SELECT 
    league_name, season, home_team AS team_name,
    SUM(CASE WHEN match_result = 'Home Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END) AS points
  FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
  GROUP BY league_name, season, home_team
  
  UNION ALL
  
  -- Deplasman maçlarından gelen puanlar
  SELECT 
    league_name, season, away_team AS team_name,
    SUM(CASE WHEN match_result = 'Away Win' THEN 3 WHEN match_result = 'Draw' THEN 1 ELSE 0 END) AS points
  FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
  GROUP BY league_name, season, away_team
),
SeasonPoints AS (
  -- Takımların sezonluk toplam puanlarını hesaplıyoruz
  SELECT 
    league_name, season, team_name,
    SUM(points) AS total_points
  FROM CombinedPoints
  GROUP BY league_name, season, team_name
)
SELECT 
  league_name,
  season,
  MAX(total_points) - MIN(total_points) AS point_gap,
  ROUND(AVG(total_points), 1) AS avg_league_points
FROM SeasonPoints
GROUP BY league_name, season
ORDER BY point_gap ASC;



/*
  ANALİZ: Liglerin Gol Verimliliği
  AMACI: Maç başına atılan gol ortalamasını (GOA) hesaplayarak, 
         hücum gücü en yüksek ve en düşük ligleri belirlemek.

  KULLANILAN MANTIKSAL ADIMLAR:
  1. SUM: Her maçtaki ev sahibi ve deplasman golleri toplanarak toplam gol sayısı bulundu.
  2. COUNT: Toplam maç sayısı hesaplandı.
  3. AVG: Toplam gol / Toplam maç formülü ile maç başına gol ortalaması elde edildi.
  4. GROUP BY & ORDER BY: Lig bazında gruplanıp, en yüksek ortalamadan en düşüğe sıralandı.
*/

SELECT 
    league_name,
    COUNT(*) AS total_matches,
    SUM(total_goals) AS total_goals,
    ROUND(AVG(total_goals), 2) AS goals_per_match
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans`
GROUP BY league_name
ORDER BY goals_per_match DESC;




/*
  ANALİZ: Boyun Hava Topu Hakimiyetine Etkisi (Mükerrer Veri Kontrolü ile)
  AMACI: Oyuncuları boy uzunluklarına göre kategorize ederek, fiziksel gelişimin kafa 
         vuruşu yeteneği ile olan korelasyonunu görselleştirmek.
*/

WITH RankedAttributes AS (
  -- Kafa vuruşu niteliğini alabilmek için ham tablodan tekilleştirme yapıyoruz
  SELECT
    pa.player_api_id,
    pa.date AS rating_date,
    pa.overall_rating,
    pa.heading_accuracy, -- Analizimiz için bu sütun şart!
    -- Her oyuncu ve tarih için girişleri numaralandır (id DESC ile en son girileni seç)
    ROW_NUMBER() OVER(PARTITION BY pa.player_api_id, pa.date ORDER BY pa.id DESC) as group_rn
  FROM `fatihdata.european_soccer_analysis.Player_Attributes` pa
),
CleanedAttributes AS (
  -- Sadece en güncel kayıtları seçiyoruz (Arkadaşının stg_ view mantığı)
  SELECT * FROM RankedAttributes WHERE group_rn = 1
)
SELECT 
    CASE 
        WHEN p.height < 175 THEN 'Kısa (175cm altı)'
        WHEN p.height BETWEEN 175 AND 185 THEN 'Orta (175-185cm)'
        ELSE 'Uzun (185cm üstü)' 
    END AS boy_kategorisi,
    ROUND(AVG(ca.heading_accuracy), 2) AS avg_heading_accuracy,
    COUNT(*) AS oyuncu_sayisi
FROM CleanedAttributes ca
JOIN `fatihdata.european_soccer_analysis.Player` p ON ca.player_api_id = p.player_api_id
-- heading_accuracy NULL olan kayıtları çıkarıyoruz
WHERE ca.heading_accuracy IS NOT NULL 
GROUP BY 1 
ORDER BY avg_heading_accuracy DESC;





/*
  ANALİZ: Takım Kadro Kalitesi ve Galibiyet Performansı
  AMACI: Oyuncu puanları (stg_oyuncu_nitelikleri) ile maç sonuçlarını (mart tablosu) 
         isim üzerinden eşleştirerek birleştiriyoruz.
*/

WITH takim_gucu AS (
    -- Maç tablosundaki tüm oyuncuları tekil hale getirip, stg_oyuncu_nitelikleri ile JOIN atıyoruz
    SELECT 
        m.home_team_api_id,
        AVG(pa.overall_rating) AS avg_kadro_kalitesi
    FROM `fatihdata.european_soccer_analysis.Match` m
    CROSS JOIN UNNEST([home_player_1, home_player_2, home_player_3, home_player_4, 
                       home_player_5, home_player_6, home_player_7, home_player_8, 
                       home_player_9, home_player_10, home_player_11]) AS player_id
    JOIN `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` pa 
      ON player_id = pa.player_api_id
    GROUP BY 1
),
takim_isimleri_ile_eslestir AS (
    -- API ID'leri takım isimlerine çevirmek için Team tablosunu kullanıyoruz
    SELECT 
        t.team_long_name,
        tg.avg_kadro_kalitesi
    FROM takim_gucu tg
    JOIN `fatihdata.european_soccer_analysis.Team` t ON tg.home_team_api_id = t.team_api_id
)
SELECT 
    m.home_team AS takim_adi,
    ROUND(ti.avg_kadro_kalitesi, 2) AS kadro_kalitesi,
    ROUND(AVG(CASE WHEN m.match_result = 'Home Win' THEN 100.0 ELSE 0.0 END), 2) AS galibiyet_yuzdesi
FROM `fatihdata.european_soccer_analysis.mart_lig_ve_takim_performans` m
JOIN takim_isimleri_ile_eslestir ti ON m.home_team = ti.team_long_name
GROUP BY 1, 2
ORDER BY kadro_kalitesi DESC;




















