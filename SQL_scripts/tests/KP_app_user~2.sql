
SELECT * from OfferGamesWithGenres;

CREATE OR REPLACE VIEW OfferGamesWithGenres AS
SELECT 
    o.OfferId,
    gp.PageID,
    gp.PageTittle,
    gp.DeveloperId,
    gp.ViewLink,
    g.GameID,
    g.GameName,
    g.DownloadLink,
    g.type AS GameType,
    gg.Ganer_ID,
    o.Price
FROM Offers o
JOIN GamePages gp ON gp.PageID = o.PageID
JOIN OfferGameLinks ogl ON ogl.OfferId = o.OfferId
JOIN Games g ON g.GameID = ogl.GameID
LEFT JOIN Games_ganers gg ON gg.GameID = g.GameID;