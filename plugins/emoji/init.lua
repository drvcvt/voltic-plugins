local voltic = require("voltic")

voltic.register({
    name = "emoji",
    prefix = "em",
    description = "Emoji picker",
})

-- Curated emoji list: {char, name, keywords}
-- Focused on most commonly-used emojis across categories
local EMOJIS = {
    -- Smileys & Emotion
    {"😀","grinning","smile happy joy face"},
    {"😃","smiley","smile happy joy face"},
    {"😄","smile","happy joy grin"},
    {"😁","grin","smile happy grin teeth"},
    {"😆","laughing","lol haha happy smile"},
    {"😂","joy","laugh cry tears happy"},
    {"🤣","rofl","rolling laughing floor"},
    {"😊","blush","happy smile joy"},
    {"😇","innocent","angel halo good"},
    {"🙂","slight_smile","smile"},
    {"😉","wink","flirt playful"},
    {"😍","heart_eyes","love crush"},
    {"🥰","smiling_hearts","love happy"},
    {"😘","kiss","love blow"},
    {"😚","kissing","love closed"},
    {"🤗","hug","hugs arms"},
    {"🤔","thinking","hmm ponder consider"},
    {"🤨","raised_eyebrow","skeptical suspicious"},
    {"😐","neutral","meh blank"},
    {"😑","expressionless","blank nothing"},
    {"🙄","eye_roll","annoyed whatever"},
    {"😏","smirk","smug"},
    {"😬","grimace","awkward teeth"},
    {"😌","relieved","relaxed calm"},
    {"😔","pensive","sad thinking"},
    {"😪","sleepy","tired"},
    {"😴","sleeping","zzz sleep"},
    {"😷","mask","sick ill"},
    {"🤒","thermometer","sick fever"},
    {"🤕","injured","bandage hurt"},
    {"🤧","sneeze","cold sick"},
    {"🥴","woozy","dizzy drunk"},
    {"😵","dizzy","spiral confused"},
    {"🤯","mind_blown","explode shock"},
    {"🤠","cowboy","hat country"},
    {"🥳","party","celebrate birthday"},
    {"😎","sunglasses","cool shades"},
    {"🤓","nerd","glasses smart"},
    {"🧐","monocle","fancy investigate"},
    {"😕","confused","puzzled"},
    {"😟","worried","concerned"},
    {"🙁","frown","sad"},
    {"☹️","frowning","sad disappointed"},
    {"😮","open_mouth","surprised oh"},
    {"😯","hushed","surprised"},
    {"😲","astonished","shocked wow"},
    {"😳","flushed","embarrassed blush"},
    {"🥺","pleading","please beg"},
    {"😢","cry","tear sad"},
    {"😭","sob","bawling cry sad"},
    {"😤","triumph","steam angry proud"},
    {"😠","angry","mad"},
    {"😡","rage","angry mad red"},
    {"🤬","cursing","swear angry"},
    {"🤯","mind_blown","explode shocked"},
    {"😱","scream","shock horror"},
    {"😨","fearful","scared afraid"},
    {"😰","anxious","sweat worried"},
    {"😥","disappointed","sad"},
    {"🤢","nauseated","sick vomit"},
    {"🤮","vomiting","sick puke"},
    {"🤡","clown","funny creepy"},
    {"👻","ghost","spooky halloween"},
    {"💀","skull","death dead"},
    {"☠️","skull_crossbones","death poison"},
    {"👽","alien","space ufo"},
    {"👾","space_invader","game retro"},
    {"🤖","robot","bot ai android"},
    {"💩","poop","shit crap"},

    -- Hearts & Symbols
    {"❤️","heart_red","love"},
    {"🧡","heart_orange","love"},
    {"💛","heart_yellow","love"},
    {"💚","heart_green","love"},
    {"💙","heart_blue","love"},
    {"💜","heart_purple","love"},
    {"🖤","heart_black","love"},
    {"🤍","heart_white","love"},
    {"🤎","heart_brown","love"},
    {"💔","broken_heart","sad breakup"},
    {"❣️","heart_exclaim","love"},
    {"💕","two_hearts","love"},
    {"💞","revolving_hearts","love"},
    {"💓","beating_heart","love pulse"},
    {"💗","growing_heart","love"},
    {"💖","sparkling_heart","love glitter"},
    {"💘","heart_arrow","cupid love"},
    {"💝","heart_ribbon","gift love"},
    {"💟","heart_decoration","love"},
    {"✨","sparkles","shiny stars magic"},
    {"⭐","star","favorite"},
    {"🌟","glowing_star","shine"},
    {"💫","dizzy","stars spinning"},
    {"⚡","zap","lightning bolt electric"},
    {"🔥","fire","hot flame lit"},
    {"💥","boom","explosion bang"},
    {"💯","hundred","perfect score 100"},
    {"✅","check","done yes ok"},
    {"✔️","checkmark","done yes"},
    {"❌","x","no wrong cross"},
    {"❎","neg_square","no wrong"},
    {"⛔","no_entry","stop forbidden"},
    {"🚫","prohibited","no forbidden"},
    {"⚠️","warning","caution alert"},
    {"❓","question","what ask"},
    {"❗","exclamation","alert emphasis"},
    {"‼️","double_exclaim","emphasis alert"},
    {"💤","zzz","sleep tired"},

    -- Hand gestures
    {"👍","thumbs_up","yes good approve like"},
    {"👎","thumbs_down","no bad disapprove dislike"},
    {"👌","ok_hand","okay good perfect"},
    {"✌️","peace","victory two"},
    {"🤞","fingers_crossed","luck hope"},
    {"🤟","love_you_gesture","ily rock"},
    {"🤘","rock_on","horns metal"},
    {"🤙","call_me","hang loose shaka"},
    {"👋","wave","hello hi bye"},
    {"🖐️","hand","five stop"},
    {"✋","raised_hand","stop high five"},
    {"🖖","vulcan","spock trek"},
    {"👏","clap","applause bravo"},
    {"🙌","raised_hands","hooray yes praise"},
    {"👐","open_hands","hug give"},
    {"🤲","palms_up","pray beg"},
    {"🙏","pray","thanks please"},
    {"🤝","handshake","deal agreement"},
    {"💪","flex","strong muscle"},
    {"👊","fist_bump","punch bro"},
    {"✊","raised_fist","power solidarity"},
    {"🫶","heart_hands","love"},

    -- Objects
    {"💻","laptop","computer code"},
    {"🖥️","desktop","computer monitor"},
    {"⌨️","keyboard","typing"},
    {"🖱️","mouse","computer click"},
    {"📱","phone","mobile cell"},
    {"📞","telephone","call"},
    {"💾","floppy","save disk"},
    {"💿","cd","disc"},
    {"📀","dvd","disc"},
    {"🔑","key","unlock access"},
    {"🔒","lock","secure closed"},
    {"🔓","unlock","open"},
    {"🔔","bell","notification ring"},
    {"📧","email","mail envelope"},
    {"📨","incoming","mail"},
    {"📦","package","box delivery"},
    {"📝","memo","note write pencil"},
    {"📋","clipboard","paste copy"},
    {"📌","pin","pushpin attach"},
    {"📎","paperclip","attach"},
    {"🗑️","trash","delete bin"},
    {"🔍","magnifying","search find"},
    {"🔎","magnify_right","search"},
    {"💡","bulb","idea light"},
    {"🎯","target","bullseye goal"},
    {"🚀","rocket","launch fast ship"},
    {"⚙️","gear","settings cog"},
    {"🔧","wrench","fix tool"},
    {"🔨","hammer","fix build"},
    {"🛠️","tools","fix build"},
    {"⌛","hourglass","time wait"},
    {"⏰","alarm","clock time"},
    {"⏱️","stopwatch","time"},
    {"📅","calendar","date"},
    {"📆","tear_calendar","date"},
    {"💰","money_bag","rich cash"},
    {"💵","dollar","money cash"},
    {"💳","credit_card","pay"},

    -- Nature
    {"🌞","sun","sunny day"},
    {"🌝","full_moon_face","night"},
    {"🌚","new_moon_face","night dark"},
    {"🌙","moon","night crescent"},
    {"⭐","star2","favorite"},
    {"☀️","sunny","weather hot"},
    {"⛅","partly_cloudy","weather"},
    {"☁️","cloud","weather"},
    {"🌧️","rain_cloud","weather"},
    {"⛈️","storm","weather lightning"},
    {"🌨️","snow_cloud","weather winter"},
    {"❄️","snowflake","cold winter snow"},
    {"☔","rain","weather umbrella"},
    {"🌈","rainbow","lgbt pride"},
    {"🌊","wave","ocean water surf"},
    {"🌳","tree","nature"},
    {"🌲","evergreen","tree christmas"},
    {"🌴","palm_tree","beach tropical"},
    {"🌵","cactus","desert"},
    {"🌻","sunflower","flower"},
    {"🌹","rose","flower love"},
    {"🌷","tulip","flower"},
    {"🌼","daisy","flower"},
    {"🍀","clover","luck irish"},
    {"🍁","maple_leaf","canada autumn"},
    {"🐶","dog","puppy pet"},
    {"🐱","cat","kitty pet"},
    {"🐭","mouse_face","animal"},
    {"🐰","rabbit","bunny"},
    {"🦊","fox","animal"},
    {"🐻","bear","animal"},
    {"🐼","panda","animal china"},
    {"🦁","lion","animal king"},
    {"🐯","tiger","animal"},
    {"🐷","pig","animal"},
    {"🐸","frog","animal"},
    {"🐵","monkey","animal"},
    {"🦉","owl","bird wise"},
    {"🦄","unicorn","magic myth"},
    {"🐝","bee","insect honey"},
    {"🦋","butterfly","insect"},

    -- Food
    {"🍎","apple","fruit red"},
    {"🍊","orange","fruit"},
    {"🍋","lemon","fruit sour"},
    {"🍌","banana","fruit"},
    {"🍉","watermelon","fruit"},
    {"🍇","grapes","fruit"},
    {"🍓","strawberry","fruit berry"},
    {"🫐","blueberries","fruit"},
    {"🍑","peach","fruit butt"},
    {"🥭","mango","fruit"},
    {"🍍","pineapple","fruit"},
    {"🥥","coconut","fruit"},
    {"🥑","avocado","fruit"},
    {"🍅","tomato","fruit"},
    {"🍔","burger","food fast"},
    {"🍟","fries","food fast"},
    {"🍕","pizza","food italian"},
    {"🌭","hotdog","food"},
    {"🥪","sandwich","food lunch"},
    {"🌮","taco","mexican food"},
    {"🌯","burrito","mexican food"},
    {"🥗","salad","food healthy"},
    {"🍝","spaghetti","pasta italian"},
    {"🍣","sushi","japanese food"},
    {"🍱","bento","japanese food"},
    {"🍜","ramen","noodle asian food"},
    {"🍲","stew","food"},
    {"🍿","popcorn","movie snack"},
    {"🧀","cheese","food"},
    {"🥚","egg","food"},
    {"🍳","cooking","fried egg"},
    {"🥓","bacon","food breakfast"},
    {"🍞","bread","loaf food"},
    {"🥐","croissant","breakfast french"},
    {"🥯","bagel","bread"},
    {"🧁","cupcake","dessert sweet"},
    {"🍰","cake","dessert sweet"},
    {"🎂","birthday_cake","party celebrate"},
    {"🍪","cookie","dessert"},
    {"🍩","donut","dessert"},
    {"🍫","chocolate","sweet"},
    {"🍬","candy","sweet"},
    {"🍭","lollipop","candy sweet"},
    {"🍦","ice_cream","dessert cold"},
    {"☕","coffee","drink caffeine"},
    {"🍵","tea","drink hot"},
    {"🍺","beer","drink alcohol"},
    {"🍷","wine","drink alcohol"},
    {"🍸","cocktail","drink alcohol"},
    {"🥂","champagne","drink celebrate"},
    {"🥤","cup","drink"},
    {"💧","droplet","water drop"},

    -- Activity
    {"⚽","soccer","sport football"},
    {"🏀","basketball","sport"},
    {"🏈","football","sport american"},
    {"⚾","baseball","sport"},
    {"🎾","tennis","sport"},
    {"🏐","volleyball","sport"},
    {"🎱","8ball","pool billiards"},
    {"🏓","ping_pong","sport"},
    {"🎮","game","controller video"},
    {"🎲","dice","random game"},
    {"🎨","art","paint palette"},
    {"🎬","clapper","movie film"},
    {"🎤","microphone","sing karaoke"},
    {"🎧","headphones","music listen"},
    {"🎵","note","music"},
    {"🎶","notes","music"},
    {"🎸","guitar","music instrument"},
    {"🎹","piano","music instrument"},
    {"🥁","drum","music instrument"},
    {"🏆","trophy","winner first"},
    {"🥇","gold_medal","winner first"},
    {"🥈","silver_medal","second"},
    {"🥉","bronze_medal","third"},
}

local function matches(emoji, q)
    if q == "" then return true end
    q = q:lower()
    if emoji[2]:lower():find(q, 1, true) then return true end
    if emoji[3]:lower():find(q, 1, true) then return true end
    return false
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    local results = {}

    if query == "" then
        -- Show a curated top set
        local top = { "👍","❤️","😂","🔥","✅","🚀","💯","🎉","✨","⭐","🙏","👀","💪","😊","🎯" }
        for i, target in ipairs(top) do
            for _, e in ipairs(EMOJIS) do
                if e[1] == target then
                    results[#results + 1] = voltic.result({
                        id = "em_" .. i,
                        name = e[1] .. "  " .. e[2],
                        description = e[3],
                        score = 300 - i,
                        meta = { value = e[1] },
                    })
                    break
                end
            end
        end
        return results
    end

    local count = 0
    for i, e in ipairs(EMOJIS) do
        if matches(e, query) then
            count = count + 1
            -- Score: exact name match > name contains > keyword
            local score = 100
            if e[2]:lower() == query:lower() then
                score = 400
            elseif e[2]:lower():find(query:lower(), 1, true) == 1 then
                score = 300 - count
            elseif e[2]:lower():find(query:lower(), 1, true) then
                score = 250 - count
            else
                score = 200 - count
            end
            results[#results + 1] = voltic.result({
                id = "em_" .. i,
                name = e[1] .. "  " .. e[2],
                description = e[3],
                score = score,
                meta = { value = e[1] },
            })
            if count >= 40 then break end
        end
    end

    if #results == 0 then
        results[#results + 1] = voltic.result({
            id = "none",
            name = "No emoji found for '" .. query .. "'",
            description = "Try: heart, fire, smile, rocket, check",
            score = 100,
        })
    end

    return results
end

function on_action(result, action)
    if result.meta and result.meta.value then
        return "copy:" .. result.meta.value
    end
end

function on_actions(result)
    if result.meta and result.meta.value then
        return {{ key = "RET", label = "copy emoji" }}
    end
    return {{ key = "RET", label = "select" }}
end
