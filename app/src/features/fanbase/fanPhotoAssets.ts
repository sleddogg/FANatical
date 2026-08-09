import gameFaceAsu from "../../../../images/FAN fotos/gameface/ASUfan.png";
import gameFaceStands from "../../../../images/FAN fotos/gameface/FB_IMG_1569253406643.jpg";
import gameFaceBucs from "../../../../images/FAN fotos/gameface/bucsfan.jpg";
import gameFaceEaglesPair from "../../../../images/FAN fotos/gameface/eagles2.jpg";
import gameFaceEagles from "../../../../images/FAN fotos/gameface/eaglesfan.jpg";
import gameFaceRaiders from "../../../../images/FAN fotos/gameface/raidersfan.jpg";
import gameFaceSeahawks from "../../../../images/FAN fotos/gameface/seahawknation.jpeg";
import gameFaceVikings from "../../../../images/FAN fotos/gameface/vikesfan.png";
import fanCaveFootball from "../../../../images/FAN fotos/FANcave/footballcave.png";
import fanCaveGiants from "../../../../images/FAN fotos/FANcave/giantscave.jpg";
import fanCaveOilers from "../../../../images/FAN fotos/FANcave/oilers fancave.jpg";
import fanCavePackers from "../../../../images/FAN fotos/FANcave/packerscave.jpg";
import fanCavePool from "../../../../images/FAN fotos/FANcave/poolcave.jpg";
import fanCaveCommanders from "../../../../images/FAN fotos/FANcave/skinscave.jpg";
import fanCaveToronto from "../../../../images/FAN fotos/FANcave/tocave.jpeg";
import memorabiliaOpeningNight from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_010610690.jpg";
import memorabiliaGoalieMask from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_175341080.jpg";
import memorabiliaGolfBag from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_175424239.jpg";
import memorabiliaFarewell from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_190623315.jpg";
import memorabiliaJerseyHistory from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_190729833.jpg";
import memorabiliaBannerNight from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_190815050.jpg";
import memorabiliaFramedStars from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_190843157.MP.jpg";
import memorabiliaSeasonCards from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_191601754.MP.jpg";
import memorabiliaGretzkyCard from "../../../../images/FAN fotos/Memorabilia/PXL_20231110_191658967.jpg";
import memorabiliaChampionshipBanners from "../../../../images/FAN fotos/Memorabilia/PXL_20231111_010056355.MP.jpg";
import memorabiliaMaskFront from "../../../../images/FAN fotos/Memorabilia/mask 1.jpg";
import memorabiliaMaskSide from "../../../../images/FAN fotos/Memorabilia/mask 2.jpg";
import memorabiliaMaskBack from "../../../../images/FAN fotos/Memorabilia/mask 3.jpg";
import memorabiliaMaskDetail from "../../../../images/FAN fotos/Memorabilia/mask 4.jpg";
import type { FanPhotoCategory, FanPhotoImage } from "./types";

function image(id: string, url: string, alt: string): FanPhotoImage {
  return { id, url, alt };
}

export const fanPhotoImages = {
  gameFaceAsu: image("game-face-asu", gameFaceAsu, "Fan wearing an elaborate red game-day outfit in the stands"),
  gameFaceStands: image("game-face-stands", gameFaceStands, "Fan showing team spirit from the stadium stands"),
  gameFaceBucs: image("game-face-bucs", gameFaceBucs, "Football fan dressed for game day"),
  gameFaceEaglesPair: image("game-face-eagles-pair", gameFaceEaglesPair, "Two fans celebrating together on game day"),
  gameFaceEagles: image("game-face-eagles", gameFaceEagles, "Fan in a full game-day outfit"),
  gameFaceRaiders: image("game-face-raiders", gameFaceRaiders, "Fan wearing a detailed stadium costume"),
  gameFaceSeahawks: image("game-face-seahawks", gameFaceSeahawks, "Fan showing team colors in a crowd"),
  gameFaceVikings: image("game-face-vikings", gameFaceVikings, "Fan in a distinctive game-day costume"),
  fanCaveFootball: image("fan-cave-football", fanCaveFootball, "A large fan room with sports displays, theater seats, and multiple screens"),
  fanCaveGiants: image("fan-cave-giants", fanCaveGiants, "A football-themed room filled with memorabilia"),
  fanCaveOilers: image("fan-cave-oilers", fanCaveOilers, "A hockey fan cave with framed collectibles and team colors"),
  fanCavePackers: image("fan-cave-packers", fanCavePackers, "A green and gold football fan room"),
  fanCavePool: image("fan-cave-pool", fanCavePool, "A fan cave with a pool table and wall displays"),
  fanCaveCommanders: image("fan-cave-commanders", fanCaveCommanders, "A football fan room with a large team display"),
  fanCaveToronto: image("fan-cave-toronto", fanCaveToronto, "A hockey fan room filled with framed jerseys and collectibles"),
  memorabiliaOpeningNight: image("memorabilia-opening-night", memorabiliaOpeningNight, "Metal opening-night ticket commemorating an inaugural season"),
  memorabiliaGoalieMask: image("memorabilia-goalie-mask", memorabiliaGoalieMask, "Signed miniature hockey goalie mask"),
  memorabiliaGolfBag: image("memorabilia-golf-bag", memorabiliaGolfBag, "Miniature team golf bag collectible"),
  memorabiliaFarewell: image("memorabilia-farewell", memorabiliaFarewell, "Farewell-night ticket, certificate, and commemorative metal ticket"),
  memorabiliaJerseyHistory: image("memorabilia-jersey-history", memorabiliaJerseyHistory, "Framed artwork showing historic team jerseys"),
  memorabiliaBannerNight: image("memorabilia-banner-night", memorabiliaBannerNight, "Framed championship banner-night display"),
  memorabiliaFramedStars: image("memorabilia-framed-stars", memorabiliaFramedStars, "Framed display honoring two generations of hockey stars"),
  memorabiliaSeasonCards: image("memorabilia-season-cards", memorabiliaSeasonCards, "Collection of season membership cards"),
  memorabiliaGretzkyCard: image("memorabilia-gretzky-card", memorabiliaGretzkyCard, "Wayne Gretzky hockey card in a protective case"),
  memorabiliaChampionshipBanners: image("memorabilia-championship-banners", memorabiliaChampionshipBanners, "Framed collection of championship banner cards"),
  memorabiliaMaskFront: image("memorabilia-mask-front", memorabiliaMaskFront, "Front view of a handmade orange and navy fan mask"),
  memorabiliaMaskSide: image("memorabilia-mask-side", memorabiliaMaskSide, "Side view of a handmade orange and navy fan mask"),
  memorabiliaMaskBack: image("memorabilia-mask-back", memorabiliaMaskBack, "Back view of a handmade orange and navy fan mask"),
  memorabiliaMaskDetail: image("memorabilia-mask-detail", memorabiliaMaskDetail, "Detail view of a handmade orange and navy fan mask"),
} as const;

export const fanPhotoCategoryCoverImages: Readonly<Record<FanPhotoCategory, FanPhotoImage>> = {
  "Game Face": fanPhotoImages.gameFaceAsu,
  "Fan Cave": fanPhotoImages.fanCaveFootball,
  Memorabilia: fanPhotoImages.memorabiliaMaskFront,
};
