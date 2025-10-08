# LangComparationBanchmark
Study project to investigate data structures speeds between Objc &amp;&amp; Swift.

Дослідження часової ефективності базових конструкцій мов Objective‑C та Swift під iOS

Навчальний проєкт виробничої практики (підготовка до магістерської роботи).
Мета — створити відтворюваний набір мікробенчмарків для Swift та Objective‑C на iOS, автоматично зберігати результати у CSV, будувати графіки (на екрані та PNG), підтримувати історію запусків і швидкий шеринг артефактів.

Що це
Цей репозиторій містить повний навчальний приклад мікробенчмаркінгу під iOS:

узгоджені Swift і Objective‑C бенчмарки (однакові сценарії);
збереження результатів: CSV по кожному кейсу та summary.csv по сесії;
графіки в застосунку (Swift Charts);
історія запусків (кожна сесія у власній папці) + видалення історії з UI.

Можливості

🔬 Мікробенчмарки: масиви, словники, множини, цикли, протокольна/динамічна диспетчеризація, замикання/blocks, ARC/autorelease, побудова тексту.
🧾 CSV логування:

Documents/Benchmarks/<timestamp>/cases/<key>_<language>.csv;
Documents/Benchmarks/<timestamp>/summary.csv (узагальнення по кейсах).



Вимоги

iOS 16+, Xcode 15+, Swift 5.9+


Швидкий старт

Клонуй репозиторій та відкрити у Xcode.
Переконайся, що SwiftUI App таргет → iOS 16+.
Запусти на реальному iPhone у Release:

Product → Scheme → Edit Scheme → Run: Release.


На головному екрані:

Run Benchmarks → запустить Swift + ObjC тести;
Далі побачиш список операцій з окремими графіками;
Share CSV & Charts → поділитися summary.csv, per‑case CSV та PNG‑графіками;
Меню … → Видалити історію → очищає Documents/Benchmarks.


Вимірювання

Таймінг у Swift: DispatchTime.now().uptimeNanoseconds;
Таймінг у ObjC: mach_absolute_time + mach_timebase_info.
Для кожного кейсу: warm‑up (не записується) + N вибірок (дефолт 10).
Повертаються наносекунди на запуск; у консолі друкуються avg/median/std/min/max.

Логування CSV

CsvLogger створює сесію Benchmarks/<timestamp>/.
На кожен кейс пишеться cases/<key>_<language>.csv із колонками:
sampleIndex,duration_ns
0,1234
1,1210
...


До summary.csv додається підсумковий рядок:
key,name,language,avg_ns,median_ns,std_ns,min_ns,max_ns,samples,count



Візуалізація та графіки

Екран OperationChartsListView:

Історія: по осі X — дати сесій, по Y — avg_ns, серія — мова.


Набір бенчмарків та ключі

Ключі мають збігатися у Swift і ObjC — це база для коректного кольорування/групування та зведень.


Масиви:

array_append_reserve — Array.append із reserveCapacity
array_append_no_reserve — Array.append без резервування
array_insert_zero — вставка в початок


Словник/Множина:

dict_lookup_hit — пошук існуючого ключа
set_contains — перевірка належності


Замикання/Blocks:

closure-non-captured — non‑capturing
closure-captured — capturing
(або зведений closure_overhead — комбінований)


ARC/autorelease:

autorelease_nsnumber


Рядки:

string_concatenation — наївна конкатенація +
string_reserve_append — reserveCapacity + append
(або зведений string_building — комбінований)


Ліцензія
Цей навчальний проєкт поширюється за умовами MIT License (онови за потреби).
Copyright (c) 2025

Подяки та корисні посилання

Swift Charts (Apple Docs) — базові компоненти, BarMark, RuleMark, модифікатори графіків.
https://developer.apple.com/documentation/Charts