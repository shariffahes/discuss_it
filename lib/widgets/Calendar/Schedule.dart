import 'package:discuss_it/models/Global.dart';
import 'package:discuss_it/widgets/Seasons/SeasonsCard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:intl/intl.dart';

class MyEvent extends Event {
  final date;
  final dotIndicator;
  final Map<String, Object> data;
  MyEvent(this.date, this.dotIndicator, this.data)
      : super(date: date, dot: dotIndicator);
}

class ScheduleScreen extends StatefulWidget {
  final List<Map<String, Object>> shows;
  ScheduleScreen(this.shows);

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  bool isDone = false;
  DateTime selectedDate = DateTime.now();
  late Animation<double> _fadeAnimation;
  late AnimationController _ac;
  Map<DateTime, List<Event>> _events = {};
  late List<Map<String, Object>> shows;
  @override
  void initState() {
    _ac =
        AnimationController(vsync: this, duration: Duration(milliseconds: 295));
    _fadeAnimation = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    shows = widget.shows;
    super.initState();
  }

  Widget _dotEventIndicator = Container(
    margin: EdgeInsets.symmetric(horizontal: 1.0),
    color: Colors.amber,
    height: 5.0,
    width: 5.0,
  );

  String title = 'My Schedule';
  List<int> added = [];
  void dismiss({List<Map<String, Object>>? currentShows}) {
    if (currentShows != null) shows = currentShows;
    if (isExpanded) {
      _ac.reset();
      setState(() {
        isExpanded = false;
        isDone = false;
      });
    } else {
      setState(() {
        isExpanded = true;
      });
      Future.delayed(Duration(milliseconds: 360), () {
        setState(() {
          isDone = true;
        });
        _ac.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    var list = ListView.builder(
      itemBuilder: (ctx, index) {
        final currentShow = shows[index];
        final String showName = currentShow['title'] as String;
        final number = currentShow['number'] as int;
        final epsName = currentShow['name'] as String;
        final season = currentShow['season'] as int;
        DateTime date = DateTime.parse(currentShow['date'] as String);
        final countDown = date.difference(DateTime.now()).inDays;
        final id = currentShow['id'] as int;

        String formattedDate = DateFormat('yyyy-MM-dd').format(date);
        date = DateTime.parse(formattedDate);

        if (_events[date] == null) {
          _events[date] = [MyEvent(date, _dotEventIndicator, currentShow)];
          added.add(id);
        } else {
          if (!added.contains(id)) {
            _events[date]!.add(MyEvent(date, _dotEventIndicator, currentShow));
            added.add(id);
          }
        }

        return SeasonCard(id, season, number, showName, epsName, countDown);
      },
      itemCount: shows.length,
    );
    return Stack(
      children: [
        GestureDetector(
          onLongPress: () {
            //dismiss();
          },
          child: Container(
              margin: EdgeInsets.only(top: screenHeight * 0.1), child: list),
        ),
        GestureDetector(
          onVerticalDragEnd: (_) {
            dismiss();
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            width: double.infinity,
            height: (isExpanded ? screenHeight * 0.52 : screenHeight * 0.10),
            decoration: BoxDecoration(
                color: Global.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(29),
                  bottomRight: Radius.circular(29),
                ),
                boxShadow: [
                  BoxShadow(
                      color: isExpanded ? Colors.black26 : Colors.transparent,
                      spreadRadius: screenHeight)
                ]),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20),
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber),
                ),
              ),
              if (isDone)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    margin: EdgeInsets.only(top: 16),
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: screenHeight * 0.4,
                    child: CalendarCarousel(
                      selectedDateTime: selectedDate,
                      markedDateCustomShapeBorder:
                          CircleBorder(side: BorderSide(color: Colors.yellow)),
                      markedDatesMap: EventList(events: _events),
                      markedDateIconBorderColor: Colors.amber,
                      weekdayTextStyle: TextStyle(color: Colors.white),
                      daysTextStyle: TextStyle(color: Colors.white),
                      weekendTextStyle: TextStyle(color: Global.accent),
                      headerTextStyle:
                          TextStyle(color: Colors.amber, fontSize: 22),
                      onDayPressed: (date, events) {
                        selectedDate = date;
                        final diff = date.difference(DateTime.now()).inHours;
                        final List<Map<String, Object>> data = [];
                        events.forEach((event) {
                          data.add((event as MyEvent).data);
                        });

                        if (diff > -24 && diff <= 0) {
                          title = 'Today';
                        } else if (diff >= 0 && diff < 24) {
                          title = 'Tomorrow';
                        } else {
                          title = 'Later';
                        }
                        dismiss(currentShows: data);
                      },
                    ),
                  ),
                ),
              if (!isExpanded)
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Icon(
                    Icons.arrow_downward_outlined,
                    color: Global.accent,
                  ),
                ),
              if (isDone)
                Icon(
                  Icons.arrow_upward_rounded,
                  color: Global.accent,
                ),
            ]),
          ),
        ),
      ],
    );
  }
}
