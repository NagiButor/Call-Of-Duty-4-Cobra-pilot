=====================================================================================
 ТЕХНИКА ИГРОКА: AH-1W SUPERCOBRA И M1A1 ABRAMS  —  справка для миссий
 скрипты: raw\maps\_playervehicle.gsc, _playervehicle_cobra.gsc, _playervehicle_abrams.gsc
=====================================================================================

1. ФАЙЛЫ СИСТЕМЫ
-------------------------------------------------------------------------------------
 raw\maps\_playervehicle.gsc          общее ядро: ввод (notifyOnCommand, поэтому работают
                                      любые переназначенные клавиши), посадка по F, состояние
                                      игрока внутри техники, камеры, HUD, засчитывание урона
                                      техники игроку (friendly fire / очки участия)
 raw\maps\_playervehicle_cobra.gsc    «Кобра»: полётная модель, 3 вида, оружие, захват целей,
                                      ловушки, предупреждения, повреждения, FARP
 raw\maps\_playervehicle_abrams.gsc   «Абрамс»: вождение (родное), камеры, перезарядка,
                                      спаренный пулемёт, броня, HUD
 raw\vehicles\cobra_pv                описание вертолёта игрока (на базе cobra_player из альфы)
 raw\vehicles\*                       стоковые описания техники — нужны sp_tool для шагов
                                      «paths» и «reflections» (он грузит всё из raw)
 raw\weapons\sp\*_pv                  оружие игрока: cobra_20mm_pv, cobra_ffar_pv,
                                      cobra_hellfire_pv, cobra_sidewinder_pv, m1a1_turret_pv
 raw\sound\cobra\*.wav                M197 (петля очереди + хвост эха), LAU-61
 raw\soundaliases\playervehicle.csv   звуки системы
 raw\english\localizedstrings\playervehicle.str   все надписи (PLAYERVEHICLE_*)

2. ПОДКЛЮЧЕНИЕ К НОВОЙ МИССИИ
-------------------------------------------------------------------------------------
2.1 Скрипт уровня (см. raw\maps\cobra_pilot.gsc как готовый пример):

    main()
    {
        maps\_cobra::main( "vehicle_cobra_helicopter_fly" );   // по строке на каждый тип техники в карте
        maps\_m1a1::main( "vehicle_m1a1_abrams" );
        maps\_t72::main( "vehicle_t72_tank" );

        maps\_playervehicle_cobra::main();        // ДО maps\_load::main()
        maps\_playervehicle_abrams::main();

        maps\_load::main();

        level.cobra  = maps\_playervehicle_cobra::setup( getent( "cobra_player", "targetname" ) );
        level.abrams = maps\_playervehicle_abrams::setup();   // ищет "abrams_player", иначе первый m1a1
    }

    Нужна только одна машина? Подключайте только её main()/setup().

2.2 Radiant
    «Кобра»      script_vehicle, model vehicle_cobra_helicopter_fly, vehicletype cobra,
                 targetname cobra_player. Флаг USABLE не нужен — посадку ведёт скрипт.
                 Можно ставить в воздух: setup() её подвесит, player_enter() сажает сразу.
    «Абрамс»     script_vehicle, model vehicle_m1a1_abrams, vehicletype m1a1,
                 targetname abrams_player (необязательно).
    FARP         trigger_multiple / trigger_radius, targetname "ammo_reload" (как в альфе) или
                 "cobra_rearm". Внутри, ниже ~30 футов и почти без скорости: каждые 0,5 с
                 +50 снарядов 20 мм, +4 НУРСа, +1 ракета, +1 ловушка, +1/12 прочности.
                 Над площадкой появляется значок FARP.
    Границы      trigger_multiple "border_outer" + "border_inner" (как в альфе): вылет за
                 outer — предупреждение и 15 секунд, чтобы вернуться через inner, иначе провал.
                 Без них вертолёт просто тормозит у стен скайбокса.
    Враги        У T-72 и SLAMRAAM в стоковых скриптах IW команда по умолчанию — ALLIES!
                 Вражеской технике ставьте ключ  script_team  axis . Иначе её нельзя захватить,
                 а «щит дружественного огня» _vehicle.gsc обнуляет весь урон от игрока.
                 (В cobra_pilot.gsc для t72 / bmp / slamraam без ключа это делается скриптом.)
    ЗРК          Чтобы SLAMRAAM / SA-6 / ZPU сами пускали ракеты по «Кобре»: script_turret 1
                 (+ необязательный ключ radius — дальность). Это система ЗРК из альфы
                 (_vehicle_missile.gsc); она бьёт по ЛЮБОЙ союзной технике в зоне прямой
                 видимости, включая танк игрока и стоящие вертолёты. От ракет спасают ловушки.

2.3 Zone CSV — блок строк системы (скопировать из zone_source\cobra_pilot.csv, строки
    от "rawfile,maps/_playervehicle.gsc" до "fx,smoke/jeepride_ffar_trail", плюс
    xanim helicopter_pilot1_idle / helicopter_pilot2_idle, xmodel cobra_interior_viewmodel,
    material tank_shell). Звуки — только с all_sp в последней колонке:
        sound,playervehicle,<имя_карты>,all_sp
    Если на карте есть солдаты: переговоры, как в стоковых уровнях IW, иначе фатальная
    ошибка «unknown sound alias 'AB_...'» в battlechatter.gsc:
        sound,ab_battlechatter,<имя_карты>,all_sp     (арабы)
        sound,us_battlechatter,<имя_карты>,all_sp     (морпехи)

3. УПРАВЛЕНИЕ (подсказки на экране показывают ВАШИ клавиши)
-------------------------------------------------------------------------------------
 «Кобра»   W/S вперёд/назад · A/D скольжение вбок · Пробел/Shift вверх/вниз · мышь — обзор,
           нос следует за взглядом · ЛКМ огонь · 1/2 (weapnext) смена оружия · ПКМ зум ·
           G ловушки · V кабина / вид сзади / камера стрелка (FLIR) · R полярность WHOT/BHOT ·
           F выйти (на земле или ниже ~3 футов почти без скорости)
 «Абрамс»  W/S ход · A/D поворот корпуса · мышь — башня · ЛКМ 120 мм (перезарядка 4 с) ·
           ПКМ спаренный пулемёт (пока держите) · Shift зум · V вид сзади / прицел наводчика ·
           F выйти (на остановке)

4. API ДЛЯ СКРИПТОВ МИССИИ
-------------------------------------------------------------------------------------
 maps\_playervehicle_cobra::player_enter( cobra )            посадить игрока сразу
 maps\_playervehicle_cobra::set_exit_allowed( cobra, false ) запретить выход (полёт по сюжету)
 maps\_playervehicle_cobra::set_boarding_enabled( cobra, false )
 maps\_playervehicle_cobra::add_target( ent, "ground"|"air", ( 0, 0, 60 ) )  своя цель
                                                             (здание, ЗРК-модель и т.п.)
 maps\_playervehicle_cobra::remove_target( ent )
 maps\_playervehicle_cobra::incoming_missile( cobra, missile )  предупредить о ракете
     (то же, что cobra notify( "incomming_missile", missile ) — так делают ЗРК альфы)
 maps\_playervehicle_abrams::player_enter( tank ) / set_exit_allowed / set_boarding_enabled
 Нотифаи уровня: "pv_cobra_boarded", "pv_cobra_exited", "pv_abrams_boarded",
                 "pv_abrams_exited" (аргумент — машина); у «Кобры» "pv_landed", "pv_takeoff".
 Цели «Кобры» — вся техника level.vehicles["axis"] + add_target(). Hellfire только по
 наземным, Sidewinder только по воздушным; захват — цель в рамке и в прямой видимости.

5. НАСТРОЙКИ (менять в main() уровня ПОСЛЕ вызова ..._cobra::main() / ..._abrams::main())
-------------------------------------------------------------------------------------
 level.pv_cobra_speed_fwd / _back / _side / _climb / _descend   скорости, mph (115/35/45/30/26)
 level.pv_cobra_accel / _decel                                  разгон / торможение, mph/с
 level.pv_cobra_yaw_speed                                       поворот носа, °/с
 level.pv_cobra_ceiling_height                                  потолок над точкой взлёта
 level.pv_cobra_chase_offset, level.pv_cobra_tads_offset         положение камер
 level.pv_cobra_default_view = "cockpit" | "chase" | "gunner"
 level.pv_cobra_flares, level.pv_cobra_health[ "easy"|"medium"|"hard"|"fu" ]
 level.pv_abrams_reload_time / _shells / _mg_ammo / _chase_distance / _chase_height
 level.pv_abrams_health[ ... ], level.pv_abrams_default_view = "chase" | "gunner"
 dvar cobrapilot_unlimited_ammo 1     бесконечный боезапас (оба аппарата)
 dvar cobrapilot_gunner_enabled 0     отключить ИИ-стрелка «Кобры» (он сам бьёт из 20 мм,
                                      пока вы стреляете ракетами)

6. КОМПИЛЯЦИЯ КАРТЫ — важные моменты
-------------------------------------------------------------------------------------
 * Порядок: BSP + Light → Paths → Reflections → Build Fastfile. Компиляция в IW3xRadiant
   делает только BSP + Light; пути и отражения — в CoD4 Compile Tools.
 * Световая сетка: cod4rad допускает не больше 1 048 576 точек. Точки идут с шагом
   32 × 32 × 64 по объёму браша lightgrid_volume. Огромный объём (вся карта до высоты 2784)
   давал ~4 млн точек, cod4rad прерывался, и карта оставалась без света — отсюда розово-
   зелёная гамма. Сейчас верх браша — 576 (крыши 304, ЗРК на крышах ~450): ~916 тыс. точек.
   Сетка нужна там, где стоят модели и персонажи; выше неё вертолёт берёт верхний слой.
 * IW3xRadiant запускает компилятор со скрытой консолью: при ошибке cod4map / cod4rad
   ждут нажатия клавиши и «висят» без нагрузки на процессор. Если компиляция не
   заканчивается — проверьте процессы cod4map.exe / cod4rad.exe в диспетчере задач.
 * Paths и Reflections запускают sp_tool с useFastFile 0 — всё грузится из raw, поэтому
   в raw\vehicles должны лежать описания всей техники с карты (сейчас там есть все стоковые).
   Ошибка «exceeded 'audio class' max 51 > 50» в этом режиме не мешает.
 * Отражения: на карте одна reflection_probe в (0 0 80). Для большой карты добавьте пробы
   над базой и над основными зонами, иначе блики везде будут «из стартовой точки».

7. ИЗВЕСТНЫЕ ОГРАНИЧЕНИЯ ДВИЖКА
-------------------------------------------------------------------------------------
 * Прямой выбор оружия клавишами 1–4 невозможен: команды +actionslot не перехватываются
   notifyOnCommand, поэтому смена оружия — weapnext/weapprev.
 * 3D-маркеры (setwaypoint) в CoD4 рисуются только «эффектными» материалами, поэтому
   прицел танка — классическое перекрестие MG42 по центру экрана (башня наводится на то,
   что под ним), а пока башня доворачивает, маленький крестик показывает, куда смотрит пушка.
 * Камера танка и камера «Кобры» сзади считаются скриптом 20 раз в секунду; при очень резком
   рывке мышью они догоняют взгляд за 1–2 кадра сервера.
 * Стрелковое оружие танк не повреждает (только взрывы и бронебойное) — как у T-72 в CoD4.
