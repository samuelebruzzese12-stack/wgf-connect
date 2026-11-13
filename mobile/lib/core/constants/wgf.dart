// =====================================================================
// Contenuti WGF (WhenGamersFail ► Lyon) – solo testi e informazioni
// pubbliche verificate (schede editoriali dei libri, canale YouTube).
// Nessun logo, immagine o personaggio disegnato: quelli arrivano solo
// dal pannello admin, con l'autorizzazione dei titolari.
// =====================================================================

class WgfMember {
  const WgfMember(this.name, this.role, this.description);
  final String name;
  final String role;
  final String description;
}

class WgfStory {
  const WgfStory(this.title, this.kind, this.description);
  final String title;
  final String kind;
  final String description;
}

class WgfLink {
  const WgfLink(this.label, this.handle, this.url);
  final String label;
  final String handle;
  final String url;
}

class QuizQuestion {
  const QuizQuestion(this.question, this.answers, this.correct, this.explanation);
  final String question;
  final List<String> answers;
  final int correct;
  final String explanation;
}

const kWgfChannelName = 'WhenGamersFail ► Lyon';
const kWgfCatchphrase = 'Ancora una volta… ciao ragazzi!';

/// La squadra WGF, come presentata nelle schede dei libri di Lyon.
const kWgfTeam = [
  WgfMember('Lyon', 'Il capo del team', 'Lo youtuber dietro WhenGamersFail: racconta avventure e misteri nel mondo di Minecraft.'),
  WgfMember('Anna', 'La compagna di avventure', 'Sempre al fianco di Lyon, nelle storie del mistero e nella caccia ai mostri.'),
  WgfMember('Cico', 'L\'alleato insostituibile', 'Con Lyon e Anna nelle Storie del mistero e nelle Storie da brivido.'),
  WgfMember('Stefano', 'Amico inseparabile', 'Parte del gruppo nelle avventure di A caccia di Herobrine e A caccia di Entity.'),
  WgfMember('Mario', 'Amico inseparabile', 'Insieme a Lyon, Anna e Stefano nelle prime grandi avventure.'),
];

/// Personaggi selezionabili nel profilo ("Personaggi WGF preferiti").
const kWgfCharacters = ['Lyon', 'Anna', 'Cico', 'Stefano', 'Mario'];

const kWgfStories = [
  WgfStory('A caccia di Herobrine', 'Libro', 'La prima grande avventura di Lyon nell\'universo Minecraft.'),
  WgfStory('A caccia di Entity', 'Libro', 'Il seguito: libri misteriosi, viaggi nel tempo, la strega Baba Yaga ed Entity, il Custode dell\'Ordine.'),
  WgfStory('Le storie del mistero', 'Serie e fumetto', 'Lyon, Anna e Cico indagano su un laboratorio sotterraneo e sui suoi prigionieri. Nato da una serie di oltre 200 episodi.'),
  WgfStory('Le storie da brivido', 'Fumetto', 'Il laboratorio è in allerta: Lyon, Anna e Cico a caccia di mostri.'),
  WgfStory('Le storie del quartiere', 'Libro', 'Un\'altra saga del mondo di Lyon.'),
];

const kWgfLegends = [
  ('Herobrine', 'La leggenda di Minecraft da cui è partita la caccia di Lyon.'),
  ('Entity', 'Il Custode dell\'Ordine, deciso a distruggere ogni cosa.'),
  ('Baba Yaga', 'La malefica strega di A caccia di Entity.'),
];

/// Canali ufficiali: si aprono nelle rispettive app.
const kWgfLinks = [
  WgfLink('YouTube', '@whengamersfail', 'https://www.youtube.com/@whengamersfail'),
  WgfLink('Instagram', '@lyonwgf', 'https://www.instagram.com/lyonwgf/'),
  WgfLink('Twitch', 'ly0nes', 'https://www.twitch.tv/ly0nes'),
];

/// Quiz "Quanto conosci i WGF?" – domande basate su fonti pubbliche.
const kWgfQuiz = [
  QuizQuestion('Come si chiama il canale YouTube di Lyon?',
      ['GamersUnited', 'WhenGamersFail', 'FailCraftItalia', 'LyonPlays'], 1,
      'Il canale è WhenGamersFail ► Lyon: per questo la community si chiama WGF.'),
  QuizQuestion('Con quale saluto si apre la presentazione del canale?',
      ['Benvenuti leoni!', 'Ciao a tutti amici!', 'Ancora una volta ciao ragazzi!', 'Eccoci di nuovo!'], 2,
      'È il saluto con cui Lyon presenta il suo canale.'),
  QuizQuestion('Chi sono gli amici inseparabili di Lyon in "A caccia di Entity"?',
      ['Anna, Stefano e Mario', 'Anna, Cico e Giorgio', 'Mario, Alex e Cico', 'Stefano, Cico e Anna'], 0,
      'Nel libro Lyon si riunisce ad Anna, Stefano e Mario.'),
  QuizQuestion('Chi accompagna Lyon nelle "Storie del mistero"?',
      ['Stefano e Mario', 'Anna e Cico', 'Solo Anna', 'Mario e Cico'], 1,
      'I protagonisti delle Storie del mistero sono Lyon, Anna e Cico.'),
  QuizQuestion('Quale strega affrontano in "A caccia di Entity"?',
      ['Morgana', 'Baba Yaga', 'Malefica', 'La Befana'], 1,
      'La malefica strega si chiama Baba Yaga.'),
  QuizQuestion('Chi è "il Custode dell\'Ordine"?',
      ['Herobrine', 'Il Wither', 'Entity', 'Notch'], 2,
      'Entity, il Custode dell\'Ordine, deciso a distruggere ogni cosa.'),
  QuizQuestion('Quale libro viene prima di "A caccia di Entity"?',
      ['Le storie del mistero', 'A caccia di Herobrine', 'Le storie da brivido', 'Le storie del quartiere'], 1,
      'A caccia di Entity è il seguito di A caccia di Herobrine.'),
  QuizQuestion('In quale videogioco sono ambientate le avventure dei libri di Lyon?',
      ['Fortnite', 'Roblox', 'Minecraft', 'Terraria'], 2,
      'Le avventure si svolgono nell\'universo Minecraft.'),
  QuizQuestion('Dove si svolgono gli strani esperimenti delle "Storie del mistero"?',
      ['In una nave pirata', 'In un laboratorio sotterraneo', 'In un castello', 'Nello spazio'], 1,
      'Un\'oscura organizzazione fa esperimenti in un laboratorio sotterraneo.'),
  QuizQuestion('Di quanti episodi era la serie da cui è nato il fumetto "Le storie del mistero"?',
      ['Circa 20', 'Circa 50', 'Oltre 200', 'Solo 1'], 2,
      'Il fumetto nasce da una serie di oltre 200 episodi.'),
];

String quizBadge(int score) {
  if (score >= 100) return 'Leone d\'oro';
  if (score >= 80) return 'Leone d\'argento';
  if (score >= 50) return 'Leone di bronzo';
  if (score > 0) return 'Cucciolo WGF';
  return '';
}
