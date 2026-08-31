class ChatEmojiCategory {
  const ChatEmojiCategory(this.label, this.emojis);
  final String label;
  final List<String> emojis;
}

const kChatEmojiCategories = <ChatEmojiCategory>[
  ChatEmojiCategory('Smileys', [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '☺️', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛',
    '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩', '🥳', '😏', '😒',
    '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢',
    '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰',
    '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄',
    '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴',
    '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺',
    '🤡', '💩', '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃',
  ]),
  ChatEmojiCategory('Gestures', [
    '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞', '🤟', '🤘',
    '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎', '✊', '👊', '🤛',
    '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦾',
    '🦵', '🦶', '👂', '👃', '🧠', '👀', '👁️', '👅', '👄', '💋', '❤️', '🧡',
    '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓',
    '💗', '💖', '💘', '💝', '💟', '💯', '💢', '💥', '💫', '💦', '💨', '🕳️',
    '💣', '💬', '👁️‍🗨️', '🗨️', '🗯️', '💭', '💤',
  ]),
  ChatEmojiCategory('People', [
    '👶', '👧', '🧒', '👦', '👩', '🧑', '👨', '👩‍🦱', '👨‍🦱', '👩‍🦰', '👨‍🦰',
    '👱‍♀️', '👱‍♂️', '👩‍🦳', '👨‍🦳', '👩‍🦲', '👨‍🦲', '🧔', '👵', '🧓', '👴',
    '👲', '👳‍♀️', '👳‍♂️', '🧕', '👮‍♀️', '👮‍♂️', '👷‍♀️', '👷‍♂️', '💂‍♀️', '💂‍♂️',
    '🕵️‍♀️', '🕵️‍♂️', '👩‍⚕️', '👨‍⚕️', '👩‍🌾', '👨‍🌾', '👩‍🍳', '👨‍🍳', '👩‍🎓', '👨‍🎓',
    '👩‍🎤', '👨‍🎤', '👩‍🏫', '👨‍🏫', '👩‍🏭', '👨‍🏭', '👩‍💻', '👨‍💻', '👩‍💼', '👨‍💼',
    '👩‍🔧', '👨‍🔧', '👩‍🔬', '👨‍🔬', '👩‍🎨', '👨‍🎨', '👩‍🚒', '👨‍🚒', '👩‍✈️', '👨‍✈️',
    '👩‍🚀', '👨‍🚀', '👩‍⚖️', '👨‍⚖️', '👰', '🤵', '👸', '🤴', '🥷', '🦸‍♀️', '🦸‍♂️',
    '🦹‍♀️', '🦹‍♂️', '🤶', '🎅', '🧙‍♀️', '🧙‍♂️', '🧝‍♀️', '🧝‍♂️', '🧛‍♀️', '🧛‍♂️',
    '🧟‍♀️', '🧟‍♂️', '🧞‍♀️', '🧞‍♂️', '🧜‍♀️', '🧜‍♂️', '🧚‍♀️', '🧚‍♂️', '👼', '🤰',
    '🤱', '🙇‍♀️', '🙇‍♂️', '💁‍♀️', '💁‍♂️', '🙅‍♀️', '🙅‍♂️', '🙆‍♀️', '🙆‍♂️',
    '🙋‍♀️', '🙋‍♂️', '🤦‍♀️', '🤦‍♂️', '🤷‍♀️', '🤷‍♂️', '🙎‍♀️', '🙎‍♂️', '🙍‍♀️',
    '🙍‍♂️', '💇‍♀️', '💇‍♂️', '💆‍♀️', '💆‍♂️', '🧖‍♀️', '🧖‍♂️', '💃', '🕺', '👯‍♀️',
    '👯‍♂️', '🕴️', '👩‍🦽', '👨‍🦽', '👩‍🦯', '👨‍🦯', '🧎‍♀️', '🧎‍♂️', '🏃‍♀️', '🏃‍♂️',
    '🧍‍♀️', '🧍‍♂️', '👫', '👭', '👬', '💑', '💏', '👪',
  ]),
  ChatEmojiCategory('Animals', [
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨', '🐯', '🦁',
    '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒', '🐔', '🐧', '🐦',
    '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝',
    '🪱', '🐛', '🦋', '🐌', '🐞', '🐜', '🪰', '🪲', '🪳', '🦟', '🦗', '🕷️',
    '🦂', '🐢', '🐍', '🦎', '🦖', '🦕', '🐙', '🦑', '🦐', '🦞', '🦀', '🐡',
    '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🦍', '🦧',
    '🦣', '🐘', '🦛', '🦏', '🐪', '🐫', '🦒', '🦘', '🦬', '🐃', '🐂', '🐄',
    '🐎', '🐖', '🐏', '🐑', '🦙', '🐐', '🦌', '🐕', '🐩', '🦮', '🐈', '🪶',
    '🐓', '🦃', '🦤', '🦚', '🦜', '🦢', '🦩', '🕊️', '🐇', '🦝', '🦨', '🦡',
    '🦫', '🦦', '🦥', '🐁', '🐀', '🐿️', '🦔', '🐾', '🐉', '🐲', '🌵', '🎄',
    '🌲', '🌳', '🌴', '🪵', '🌱', '🌿', '☘️', '🍀', '🎍', '🪴', '🎋', '🍃',
    '🍂', '🍁', '🍄', '🐚', '🪨', '🌾', '💐', '🌷', '🌹', '🥀', '🌺', '🌸',
    '🌼', '🌻', '🌞', '🌝', '🌛', '🌜', '🌚', '🌕', '🌖', '🌗', '🌘', '🌑',
    '🌒', '🌓', '🌔', '🌙', '🌎', '🌍', '🌏', '🪐', '💫', '⭐', '🌟', '✨',
    '⚡', '☄️', '💥', '🔥', '🌪️', '🌈', '☀️', '🌤️', '⛅', '🌥️', '☁️', '🌦️',
    '🌧️', '⛈️', '🌩️', '🌨️', '❄️', '☃️', '⛄', '🌬️', '💨', '💧', '💦', '☔',
    '☂️', '🌊', '🌫️',
  ]),
  ChatEmojiCategory('Food', [
    '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐', '🍈', '🍒',
    '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬', '🥒', '🌶️',
    '🫑', '🌽', '🥕', '🫒', '🧄', '🧅', '🥔', '🍠', '🥐', '🥯', '🍞', '🥖',
    '🥨', '🧀', '🥚', '🍳', '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🦴',
    '🌭', '🍔', '🍟', '🍕', '🫓', '🥪', '🥙', '🧆', '🌮', '🌯', '🫔', '🥗',
    '🥘', '🫕', '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🦪', '🍤',
    '🍙', '🍚', '🍘', '🍥', '🥠', '🥮', '🍢', '🍡', '🍧', '🍨', '🍦', '🥧',
    '🧁', '🍰', '🎂', '🍮', '🍭', '🍬', '🍫', '🍿', '🍩', '🍪', '🌰', '🥜',
    '🍯', '🥛', '🍼', '🫖', '☕', '🍵', '🧃', '🥤', '🧋', '🍶', '🍺', '🍻',
    '🥂', '🍷', '🥃', '🍸', '🍹', '🧉', '🍾', '🧊', '🥄', '🍴', '🍽️', '🥣',
    '🥡', '🥢', '🧂',
  ]),
  ChatEmojiCategory('Travel', [
    '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐', '🛻', '🚚',
    '🚛', '🚜', '🦯', '🦽', '🦼', '🛴', '🚲', '🛵', '🏍️', '🛺', '🚨', '🚔',
    '🚍', '🚘', '🚖', '🚡', '🚠', '🚟', '🚃', '🚋', '🚞', '🚝', '🚄', '🚅',
    '🚈', '🚂', '🚆', '🚇', '🚊', '🚉', '✈️', '🛫', '🛬', '🛩️', '💺', '🛰️',
    '🚀', '🛸', '🚁', '🛶', '⛵', '🚤', '🛥️', '🛳️', '⛴️', '🚢', '⚓', '🪝',
    '⛽', '🚧', '🚦', '🚥', '🚏', '🗺️', '🗿', '🗽', '🗼', '🏰', '🏯', '🏟️',
    '🎡', '🎢', '🎠', '⛲', '⛱️', '🏖️', '🏝️', '🏜️', '🌋', '⛰️', '🏔️', '🗻',
    '🏕️', '⛺', '🛖', '🏠', '🏡', '🏘️', '🏚️', '🏗️', '🏭', '🏢', '🏬', '🏣',
    '🏤', '🏥', '🏦', '🏨', '🏪', '🏫', '🏩', '💒', '🏛️', '⛪', '🕌', '🕍',
    '🛕', '🕋', '⛩️', '🛤️', '🛣️', '🗾', '🎑', '🏞️', '🌅', '🌄', '🌠', '🎇',
    '🎆', '🌇', '🌆', '🏙️', '🌃', '🌌', '🌉', '🌁',
  ]),
  ChatEmojiCategory('Activities', [
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱', '🪀', '🏓',
    '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳', '🪁', '🏹', '🎣', '🤿',
    '🥊', '🥋', '🎽', '🛹', '🛼', '🛷', '⛸️', '🥌', '🎿', '⛷️', '🏂', '🪂',
    '🏋️‍♀️', '🏋️‍♂️', '🤼‍♀️', '🤼‍♂️', '🤸‍♀️', '🤸‍♂️', '⛹️‍♀️', '⛹️‍♂️', '🤺', '🤾‍♀️',
    '🤾‍♂️', '🏌️‍♀️', '🏌️‍♂️', '🏇', '🧘‍♀️', '🧘‍♂️', '🏄‍♀️', '🏄‍♂️', '🏊‍♀️', '🏊‍♂️',
    '🤽‍♀️', '🤽‍♂️', '🚣‍♀️', '🚣‍♂️', '🧗‍♀️', '🧗‍♂️', '🚵‍♀️', '🚵‍♂️', '🚴‍♀️',
    '🚴‍♂️', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️', '🏵️', '🎗️', '🎫', '🎟️',
    '🎪', '🤹‍♀️', '🤹‍♂️', '🎭', '🩰', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁',
    '🪘', '🎷', '🎺', '🪗', '🎸', '🪕', '🎻', '🎲', '♟️', '🎯', '🎳', '🎮',
    '🎰', '🧩',
  ]),
  ChatEmojiCategory('Objects', [
    '⌚', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️', '🗜️', '💽',
    '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥', '📽️', '🎞️', '📞', '☎️',
    '📟', '📠', '📺', '📻', '🎙️', '🎚️', '🎛️', '🧭', '⏱️', '⏲️', '⏰', '🕰️',
    '⌛', '⏳', '📡', '🔋', '🔌', '💡', '🔦', '🕯️', '🪔', '🧯', '🛢️', '💸',
    '💵', '💴', '💶', '💷', '🪙', '💰', '💳', '💎', '⚖️', '🪜', '🧰', '🪛',
    '🔧', '🔨', '⚒️', '🛠️', '⛏️', '🪚', '🔩', '⚙️', '🪤', '🧱', '⛓️', '🧲',
    '🔫', '💣', '🧨', '🪓', '🔪', '🗡️', '⚔️', '🛡️', '🚬', '⚰️', '🪦', '⚱️',
    '🏺', '🔮', '📿', '🧿', '💈', '⚗️', '🔭', '🔬', '🕳️', '🩹', '🩺', '💊',
    '💉', '🩸', '🧬', '🦠', '🧫', '🧪', '🌡️', '🧹', '🪠', '🧺', '🧻', '🚽',
    '🚰', '🚿', '🛁', '🛀', '🧼', '🪥', '🪒', '🧽', '🪣', '🧴', '🛎️', '🔑',
    '🗝️', '🚪', '🪑', '🛋️', '🛏️', '🛌', '🧸', '🪆', '🖼️', '🪞', '🪟', '🛍️',
    '🛒', '🎁', '🎈', '🎏', '🎀', '🪄', '🪅', '🎊', '🎉', '🎎', '🏮', '🎐',
    '🧧', '✉️', '📩', '📨', '📧', '💌', '📥', '📤', '📦', '🏷️', '🪧', '📪',
    '📫', '📬', '📭', '📮', '📯', '📜', '📃', '📄', '📑', '🧾', '📊', '📈',
    '📉', '🗒️', '🗓️', '📆', '📅', '🗑️', '📇', '🗃️', '🗳️', '🗄️', '📋', '📁',
    '📂', '🗂️', '🗞️', '📰', '📓', '📔', '📒', '📕', '📗', '📘', '📙', '📚',
    '📖', '🔖', '🧷', '🔗', '📎', '🖇️', '📐', '📏', '🧮', '📌', '📍', '✂️',
    '🖊️', '🖋️', '✒️', '🖌️', '🖍️', '📝', '✏️', '🔍', '🔎', '🔏', '🔐', '🔒',
    '🔓',
  ]),
  ChatEmojiCategory('Symbols', [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕',
    '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️',
    '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎', '♈', '♉', '♊', '♋', '♌',
    '♍', '♎', '♏', '♐', '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️',
    '📴', '📳', '🈶', '🈚', '🈸', '🈺', '🈷️', '✴️', '🆚', '💮', '🉐', '㊙️',
    '㊗️', '🈴', '🈵', '🈹', '🈲', '🅰️', '🅱️', '🆎', '🆑', '🅾️', '🆘', '❌',
    '⭕', '🛑', '⛔', '📛', '🚫', '💯', '💢', '♨️', '🚷', '🚯', '🚳', '🚱',
    '🔞', '📵', '🚭', '❗', '❕', '❓', '❔', '‼️', '⁉️', '🔅', '🔆', '〽️',
    '⚠️', '🚸', '🔱', '⚜️', '🔰', '♻️', '✅', '🈯', '💹', '❇️', '✳️', '❎',
    '🌐', '💠', 'Ⓜ️', '🌀', '💤', '🏧', '🚾', '♿', '🅿️', '🛗', '🈳', '🈂️',
    '🛂', '🛃', '🛄', '🛅', '🚹', '🚺', '🚼', '⚧', '🚻', '🚮', '🎦', '📶',
    '🈁', '🔣', 'ℹ️', '🔤', '🔡', '🔠', '🆖', '🆗', '🆙', '🆒', '🆕', '🆓',
    '0️⃣', '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟', '🔢',
    '#️⃣', '*️⃣', '⏏️', '▶️', '⏸️', '⏯️', '⏹️', '⏺️', '⏭️', '⏮️', '⏩', '⏪',
    '⏫', '⏬', '◀️', '🔼', '🔽', '➡️', '⬅️', '⬆️', '⬇️', '↗️', '↘️', '↙️',
    '↖️', '↕️', '↔️', '↪️', '↩️', '⤴️', '⤵️', '🔀', '🔁', '🔂', '🔄', '🔃',
    '🎵', '🎶', '➕', '➖', '➗', '✖️', '♾️', '💲', '💱', '™️', '©️', '®️',
    '〰️', '➰', '➿', '🔚', '🔙', '🔛', '🔝', '🔜', '✔️', '☑️', '🔘', '🔴',
    '🟠', '🟡', '🟢', '🔵', '🟣', '⚫', '⚪', '🟤', '🔺', '🔻', '🔸', '🔹',
    '🔶', '🔷', '🔳', '🔲', '▪️', '▫️', '◾', '◽', '◼️', '◻️', '🟥', '🟧',
    '🟨', '🟩', '🟦', '🟪', '⬛', '⬜', '🟫', '🔈', '🔇', '🔉', '🔊', '🔔',
    '🔕', '📣', '📢', '👁️‍🗨️', '💬', '💭', '🗯️', '♠️', '♣️', '♥️', '♦️', '🃏',
    '🎴', '🀄', '🕐', '🕑', '🕒', '🕓', '🕔', '🕕', '🕖', '🕗', '🕘', '🕙',
    '🕚', '🕛',
  ]),
  ChatEmojiCategory('Flags', [
    '🏳️', '🏴', '🏁', '🚩', '🏳️‍🌈', '🏳️‍⚧️', '🏴‍☠️', '🇮🇳', '🇺🇸', '🇬🇧', '🇨🇦',
    '🇦🇺', '🇩🇪', '🇫🇷', '🇯🇵', '🇨🇳', '🇰🇷', '🇧🇷', '🇮🇹', '🇪🇸', '🇷🇺', '🇦🇪',
    '🇸🇦', '🇵🇰', '🇧🇩', '🇱🇰', '🇳🇵', '🇧🇹', '🇸🇬', '🇲🇾', '🇮🇩', '🇹🇭', '🇻🇳',
    '🇵🇭', '🇳🇿', '🇿🇦', '🇳🇬', '🇪🇬', '🇰🇪', '🇲🇽', '🇦🇷', '🇨🇱', '🇳🇱', '🇸🇪',
    '🇳🇴', '🇩🇰', '🇫🇮', '🇵🇱', '🇺🇦', '🇹🇷', '🇬🇷', '🇵🇹', '🇮🇪', '🇨🇭', '🇦🇹',
  ]),
];

final kAllChatEmojis = <String>[
  for (final category in kChatEmojiCategories) ...category.emojis,
];

/// Keyword blobs used by the emoji search box (names, aliases, feelings).
final Map<String, String> kChatEmojiKeywords = _buildChatEmojiKeywords();

bool chatEmojiMatchesQuery(String emoji, String query, {String? category}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (emoji.contains(q)) return true;
  if (category != null && category.toLowerCase().contains(q)) return true;
  final blob = kChatEmojiKeywords[emoji];
  return blob != null && blob.contains(q);
}

List<ChatEmojiCategory> searchChatEmojis(String query) {
  final q = query.trim();
  if (q.isEmpty) return kChatEmojiCategories;
  final results = <ChatEmojiCategory>[];
  for (final cat in kChatEmojiCategories) {
    final hits = cat.emojis.where((e) => chatEmojiMatchesQuery(e, q, category: cat.label)).toList();
    if (hits.isNotEmpty) results.add(ChatEmojiCategory(cat.label, hits));
  }
  return results;
}

Map<String, String> _buildChatEmojiKeywords() {
  final m = <String, String>{};
  void add(String emoji, String words) => m[emoji] = words.toLowerCase();

  add('😀', 'grinning smile happy face joy cheerful grin');
  add('😃', 'smiley smile happy face joy open mouth');
  add('😄', 'smile happy grinning squint joy laugh');
  add('😁', 'beaming grin smile happy teeth');
  add('😆', 'laughing satisfied laugh happy xd');
  add('😅', 'sweat smile nervous awkward relief');
  add('😂', 'joy tears laugh lol crying laughing funny haha');
  add('🤣', 'rofl rolling floor laugh funny lol');
  add('🥲', 'smiling tear bittersweet proud emotional');
  add('☺️', 'smiling blush relaxed happy kind');
  add('😊', 'blush smile happy kind warm shy');
  add('😇', 'angel innocent halo bless saint');
  add('🙂', 'slight smile happy fine okay');
  add('🙃', 'upside down sarcasm silly ironic');
  add('😉', 'wink flirt joke tease');
  add('😌', 'relieved calm peace content');
  add('😍', 'heart eyes love crush adore');
  add('🥰', 'smiling hearts love adore affection');
  add('😘', 'kiss blow kiss love flirt');
  add('😗', 'kissing face kiss');
  add('😙', 'kissing smiling eyes kiss');
  add('😚', 'kissing closed eyes kiss');
  add('😋', 'yum delicious savouring tasty food');
  add('😛', 'tongue playful tease');
  add('😝', 'squinting tongue playful');
  add('😜', 'wink tongue joke crazy');
  add('🤪', 'zany goofy crazy wild');
  add('🤨', 'raised eyebrow skeptic hmm suspicious');
  add('🧐', 'monocle inspect curious consider');
  add('🤓', 'nerd geek glasses smart');
  add('😎', 'cool sunglasses awesome');
  add('🥸', 'disguise incognito glasses');
  add('🤩', 'star struck wow excited star eyes');
  add('🥳', 'party celebrate birthday congrats');
  add('😏', 'smirk smirking suggestive');
  add('😒', 'unamused meh annoyed bored');
  add('😞', 'disappointed sad down');
  add('😔', 'pensive sad sorry');
  add('😟', 'worried concern anxious');
  add('😕', 'confused unsure');
  add('🙁', 'slight frown sad');
  add('☹️', 'frown sad unhappy');
  add('😣', 'persevere strain');
  add('😖', 'confounded frustrated');
  add('😫', 'tired exhausted');
  add('😩', 'weary tired upset');
  add('🥺', 'pleading puppy eyes please cute');
  add('😢', 'cry sad tear');
  add('😭', 'sob bawling cry loudly sad');
  add('😤', 'triumph huff steam angry');
  add('😠', 'angry mad');
  add('😡', 'pouting rage angry mad red');
  add('🤬', 'cursing swear angry symbols');
  add('🤯', 'exploding head mind blown shocked');
  add('😳', 'flushed embarrassed shocked');
  add('🥵', 'hot sweating heat');
  add('🥶', 'cold freezing blue');
  add('😱', 'scream shock fear scared');
  add('😨', 'fearful scared afraid');
  add('😰', 'anxious sweat nervous');
  add('😥', 'sad relieved disappointed');
  add('😓', 'downcast sweat sorry');
  add('🤗', 'hug hugging care');
  add('🤔', 'thinking hmm consider wonder');
  add('🤭', 'oops giggle hand over mouth');
  add('🤫', 'shush quiet secret');
  add('🤥', 'lying pinocchio lie');
  add('😶', 'no mouth silent speechless');
  add('😐', 'neutral meh blank');
  add('😑', 'expressionless blank');
  add('😬', 'grimace awkward oops');
  add('🙄', 'eyeroll eye roll whatever');
  add('😯', 'hushed surprise');
  add('😦', 'frown open mouth');
  add('😧', 'anguished shock');
  add('😮', 'open mouth wow surprise');
  add('😲', 'astonished shocked wow');
  add('🥱', 'yawn tired bored sleepy');
  add('😴', 'sleep sleeping zzz tired');
  add('🤤', 'drool hungry');
  add('😪', 'sleepy tired');
  add('😵', 'dizzy dead knocked out');
  add('🤐', 'zipper mouth secret quiet');
  add('🥴', 'woozy drunk dizzy');
  add('🤢', 'nauseated sick green');
  add('🤮', 'vomit sick puke');
  add('🤧', 'sneeze sick tissue');
  add('😷', 'mask sick covid doctor');
  add('🤒', 'thermometer fever sick');
  add('🤕', 'bandage hurt injury');
  add('🤑', 'money mouth rich cash');
  add('🤠', 'cowboy hat western');
  add('😈', 'smiling devil evil horns');
  add('👿', 'angry devil imp');
  add('👹', 'ogre mask japanese');
  add('👺', 'goblin mask');
  add('🤡', 'clown funny circus');
  add('💩', 'poop poo dung');
  add('👻', 'ghost halloween boo');
  add('💀', 'skull dead death');
  add('☠️', 'skull crossbones death pirate');
  add('👽', 'alien ufo space');
  add('👾', 'alien monster game space invader');
  add('🤖', 'robot bot ai');
  add('🎃', 'pumpkin halloween jack o lantern');

  add('👋', 'wave hello hi bye greeting');
  add('🤚', 'raised back hand stop');
  add('🖐️', 'hand fingers splayed palm');
  add('✋', 'raised hand stop high five');
  add('🖖', 'vulcan spock live long');
  add('👌', 'ok okay perfect');
  add('🤌', 'pinched fingers italian');
  add('🤏', 'pinch small tiny');
  add('✌️', 'peace victory two');
  add('🤞', 'crossed fingers luck hope');
  add('🤟', 'love you gesture ily');
  add('🤘', 'horns rock metal');
  add('🤙', 'call me shaka phone');
  add('👈', 'point left');
  add('👉', 'point right');
  add('👆', 'point up');
  add('🖕', 'middle finger');
  add('👇', 'point down');
  add('☝️', 'index up point');
  add('👍', 'thumbs up like yes good approve');
  add('👎', 'thumbs down dislike no bad');
  add('✊', 'fist raise power');
  add('👊', 'punch fist bump');
  add('🤛', 'left fist bump');
  add('🤜', 'right fist bump');
  add('👏', 'clap applause bravo');
  add('🙌', 'hooray praise hands raised');
  add('👐', 'open hands');
  add('🤲', 'palms up prayer receive');
  add('🤝', 'handshake deal agree');
  add('🙏', 'pray please thanks namaste folded');
  add('✍️', 'writing write pen');
  add('💅', 'nails manicure sassy');
  add('🤳', 'selfie phone');
  add('💪', 'muscle strong flex gym');
  add('🦾', 'mechanical arm robot');
  add('🦵', 'leg kick');
  add('🦶', 'foot kick');
  add('👂', 'ear hear listen');
  add('👃', 'nose smell');
  add('🧠', 'brain smart think');
  add('👀', 'eyes look see watching');
  add('👁️', 'eye look');
  add('👅', 'tongue');
  add('👄', 'mouth lips');
  add('💋', 'kiss mark lips');
  add('❤️', 'red heart love like');
  add('🧡', 'orange heart love');
  add('💛', 'yellow heart love');
  add('💚', 'green heart love');
  add('💙', 'blue heart love');
  add('💜', 'purple heart love');
  add('🖤', 'black heart love');
  add('🤍', 'white heart love');
  add('🤎', 'brown heart love');
  add('💔', 'broken heart heartbreak sad');
  add('❣️', 'heart exclamation love');
  add('💕', 'two hearts love');
  add('💞', 'revolving hearts love');
  add('💓', 'beating heart love');
  add('💗', 'growing heart love');
  add('💖', 'sparkling heart love');
  add('💘', 'heart arrow cupid love');
  add('💝', 'heart ribbon gift love');
  add('💟', 'heart decoration love');
  add('💯', 'hundred 100 perfect score');
  add('💢', 'anger comic mad');
  add('💥', 'collision boom explode');
  add('💫', 'dizzy star sparkle');
  add('💦', 'sweat drops water splash');
  add('💨', 'dash wind fast');
  add('🕳️', 'hole');
  add('💣', 'bomb explode');
  add('💬', 'speech balloon comment chat');
  add('👁️‍🗨️', 'eye in speech bubble witness');
  add('🗨️', 'left speech bubble chat');
  add('🗯️', 'anger bubble');
  add('💭', 'thought bubble think dream');
  add('💤', 'zzz sleep');

  add('🐶', 'dog puppy pet animal');
  add('🐱', 'cat kitten pet animal');
  add('🐭', 'mouse animal');
  add('🐹', 'hamster pet');
  add('🐰', 'rabbit bunny');
  add('🦊', 'fox animal');
  add('🐻', 'bear animal');
  add('🐼', 'panda bear');
  add('🐻‍❄️', 'polar bear');
  add('🐨', 'koala animal');
  add('🐯', 'tiger animal');
  add('🦁', 'lion animal');
  add('🐮', 'cow animal');
  add('🐷', 'pig animal');
  add('🐸', 'frog animal');
  add('🐵', 'monkey animal');
  add('🙈', 'see no evil monkey');
  add('🙉', 'hear no evil monkey');
  add('🙊', 'speak no evil monkey');
  add('🐔', 'chicken hen bird');
  add('🐧', 'penguin bird');
  add('🐦', 'bird');
  add('🐤', 'chick baby bird');
  add('🦄', 'unicorn magic');
  add('🐝', 'bee honey insect');
  add('🦋', 'butterfly insect');
  add('🐢', 'turtle animal');
  add('🐍', 'snake animal');
  add('🐙', 'octopus animal');
  add('🐬', 'dolphin animal');
  add('🐳', 'whale animal');
  add('🦈', 'shark animal');
  add('🐘', 'elephant animal');
  add('🦒', 'giraffe animal');
  add('🦓', 'zebra animal');
  add('🐕', 'dog pet');
  add('🐈', 'cat pet');
  add('🌹', 'rose flower love');
  add('🌸', 'cherry blossom flower');
  add('🌻', 'sunflower flower');
  add('🌞', 'sun face sunny');
  add('⭐', 'star');
  add('🌟', 'glowing star sparkle');
  add('✨', 'sparkles shine magic glitter');
  add('⚡', 'zap lightning bolt electricity');
  add('🔥', 'fire lit hot flame');
  add('🌈', 'rainbow pride weather');
  add('☀️', 'sun sunny weather');
  add('⛅', 'sun behind cloud weather');
  add('🌧️', 'rain weather');
  add('❄️', 'snow snowflake cold winter');
  add('⛄', 'snowman winter');
  add('🌊', 'ocean wave water');

  add('🍏', 'green apple fruit food');
  add('🍎', 'red apple fruit food');
  add('🍐', 'pear fruit food');
  add('🍊', 'orange tangerine fruit food');
  add('🍋', 'lemon fruit food');
  add('🍌', 'banana fruit food');
  add('🍉', 'watermelon fruit food');
  add('🍇', 'grapes fruit food');
  add('🍓', 'strawberry fruit food');
  add('🫐', 'blueberry fruit food');
  add('🍒', 'cherries fruit food');
  add('🍑', 'peach fruit food');
  add('🥭', 'mango fruit food');
  add('🍍', 'pineapple fruit food');
  add('🥥', 'coconut fruit food');
  add('🥝', 'kiwi fruit food');
  add('🍅', 'tomato food vegetable');
  add('🍆', 'eggplant aubergine food');
  add('🥑', 'avocado food');
  add('🥦', 'broccoli vegetable food');
  add('🥕', 'carrot vegetable food');
  add('🌽', 'corn food');
  add('🌶️', 'chili pepper hot spicy food');
  add('🍞', 'bread food');
  add('🧀', 'cheese food');
  add('🥚', 'egg food');
  add('🍳', 'cooking fried egg breakfast food');
  add('🥞', 'pancake breakfast food');
  add('🥓', 'bacon food');
  add('🥩', 'steak meat food');
  add('🍗', 'poultry chicken food');
  add('🍔', 'hamburger burger food');
  add('🍟', 'fries food');
  add('🍕', 'pizza food');
  add('🌭', 'hotdog food');
  add('🥪', 'sandwich food');
  add('🌮', 'taco food');
  add('🌯', 'burrito food');
  add('🥗', 'salad food');
  add('🍝', 'spaghetti pasta food');
  add('🍜', 'ramen noodles food');
  add('🍣', 'sushi food');
  add('🍱', 'bento food');
  add('🍦', 'ice cream dessert food');
  add('🍩', 'doughnut donut dessert food');
  add('🍪', 'cookie dessert food');
  add('🎂', 'birthday cake dessert food party');
  add('🍰', 'shortcake cake dessert food');
  add('🧁', 'cupcake dessert food');
  add('🍫', 'chocolate dessert food');
  add('🍿', 'popcorn food movie');
  add('☕', 'coffee tea hot drink cafe');
  add('🍵', 'tea teacup drink');
  add('🧃', 'juice box drink');
  add('🥤', 'cup straw soda drink');
  add('🍺', 'beer drink alcohol');
  add('🍻', 'beers cheers drink');
  add('🥂', 'champagne cheers toast drink');
  add('🍷', 'wine drink alcohol');
  add('🍸', 'cocktail drink');
  add('🍹', 'tropical drink cocktail');

  add('🚗', 'car automobile travel');
  add('🚕', 'taxi cab travel');
  add('🚌', 'bus travel');
  add('🏎️', 'race car fast travel');
  add('🚓', 'police car travel');
  add('🚑', 'ambulance hospital travel');
  add('🚒', 'fire engine truck travel');
  add('🚚', 'truck delivery travel');
  add('🚲', 'bicycle bike travel');
  add('🛵', 'scooter travel');
  add('🏍️', 'motorcycle travel');
  add('✈️', 'airplane plane flight travel');
  add('🚀', 'rocket space launch travel');
  add('🛸', 'ufo flying saucer travel');
  add('🚁', 'helicopter travel');
  add('⛵', 'sailboat boat travel');
  add('🚢', 'ship boat travel');
  add('🏠', 'house home building');
  add('🏡', 'house garden home');
  add('🏢', 'office building');
  add('🏥', 'hospital building');
  add('🏦', 'bank building');
  add('🏫', 'school building');
  add('🏰', 'castle building');
  add('⛺', 'tent camping');
  add('🌅', 'sunrise morning');
  add('🌄', 'sunrise mountain');

  add('⚽', 'soccer football sport ball');
  add('🏀', 'basketball sport ball');
  add('🏈', 'american football sport');
  add('⚾', 'baseball sport');
  add('🎾', 'tennis sport');
  add('🏐', 'volleyball sport');
  add('🎱', 'billiards pool 8ball');
  add('🏓', 'ping pong table tennis');
  add('🏸', 'badminton sport');
  add('⛳', 'golf flag sport');
  add('🥊', 'boxing glove sport');
  add('🎯', 'bullseye dart target');
  add('🎮', 'video game controller play');
  add('🎲', 'dice game');
  add('🧩', 'puzzle piece');
  add('🎵', 'music note song');
  add('🎶', 'music notes song');
  add('🎤', 'microphone sing karaoke');
  add('🎧', 'headphone music');
  add('🎸', 'guitar music');
  add('🎹', 'piano keyboard music');
  add('🎺', 'trumpet music');
  add('🥁', 'drum music');
  add('🏆', 'trophy win champion award');
  add('🥇', 'gold medal first win');
  add('🥈', 'silver medal second');
  add('🥉', 'bronze medal third');
  add('🎉', 'party popper celebrate congrats');
  add('🎊', 'confetti ball party');
  add('🎈', 'balloon party');
  add('🎁', 'gift present wrapped');

  add('💻', 'laptop computer work');
  add('📱', 'phone mobile iphone');
  add('⌚', 'watch apple time');
  add('📷', 'camera photo');
  add('📹', 'video camera');
  add('🎥', 'movie camera film');
  add('💡', 'bulb idea light');
  add('🔦', 'flashlight torch');
  add('💰', 'money bag cash rich');
  add('💳', 'credit card payment');
  add('💎', 'gem diamond jewel');
  add('🔑', 'key password');
  add('🔒', 'lock locked secure');
  add('📬', 'mailbox mail');
  add('📦', 'package box parcel');
  add('📎', 'paperclip clip');
  add('📌', 'pushpin pin');
  add('📝', 'memo note write');
  add('📒', 'ledger notebook');
  add('📚', 'books study');
  add('📖', 'open book read');
  add('✂️', 'scissors cut');
  add('🖊️', 'pen write');
  add('✅', 'check mark done yes complete');
  add('❌', 'cross mark no delete wrong');
  add('❓', 'question mark help');
  add('❗', 'exclamation alert');
  add('⚠️', 'warning caution');
  add('♻️', 'recycle');
  add('✔️', 'check heavy yes');
  add('🔴', 'red circle');
  add('🟠', 'orange circle');
  add('🟡', 'yellow circle');
  add('🟢', 'green circle');
  add('🔵', 'blue circle');
  add('🟣', 'purple circle');
  add('⚫', 'black circle');
  add('⚪', 'white circle');

  add('🇮🇳', 'india indian flag');
  add('🇺🇸', 'usa america united states flag');
  add('🇬🇧', 'uk britain england flag');
  add('🇨🇦', 'canada flag');
  add('🇦🇺', 'australia flag');
  add('🇯🇵', 'japan flag');
  add('🇩🇪', 'germany flag');
  add('🇫🇷', 'france flag');
  add('🇧🇷', 'brazil flag');
  add('🇨🇳', 'china flag');
  add('🇰🇷', 'korea flag');
  add('🇮🇹', 'italy flag');
  add('🇪🇸', 'spain flag');
  add('🇷🇺', 'russia flag');
  add('🇦🇪', 'uae dubai flag');
  add('🇸🇦', 'saudi arabia flag');
  add('🇵🇰', 'pakistan flag');
  add('🇧🇩', 'bangladesh flag');
  add('🇱🇰', 'sri lanka flag');
  add('🇳🇵', 'nepal flag');
  add('🇸🇬', 'singapore flag');
  add('🇲🇾', 'malaysia flag');
  add('🇮🇩', 'indonesia flag');
  add('🏳️', 'white flag');
  add('🏴', 'black flag');
  add('🏁', 'chequered flag race finish');
  add('🚩', 'triangular flag');
  add('🏳️‍🌈', 'rainbow flag pride lgbt');

  add('👶', 'baby infant child');
  add('👧', 'girl child');
  add('👦', 'boy child');
  add('👩', 'woman female');
  add('👨', 'man male');
  add('🧑', 'person adult');
  add('👵', 'old woman grandma');
  add('👴', 'old man grandpa');
  add('👮‍♀️', 'police woman cop');
  add('👮‍♂️', 'police man cop');
  add('👩‍💻', 'woman technologist developer coder');
  add('👨‍💻', 'man technologist developer coder');
  add('👩‍💼', 'woman office worker');
  add('👨‍💼', 'man office worker');
  add('👸', 'princess');
  add('🤴', 'prince');
  add('🎅', 'santa christmas');
  add('💃', 'dancer woman dance');
  add('🕺', 'dancer man dance');
  add('👪', 'family');

  for (final cat in kChatEmojiCategories) {
    for (final emoji in cat.emojis) {
      final extra = cat.label.toLowerCase();
      final prev = m[emoji];
      m[emoji] = prev == null || prev.isEmpty ? extra : '$prev $extra';
    }
  }

  return m;
}
