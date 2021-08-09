import 'package:discuss_it/main.dart';
import 'package:discuss_it/models/Enums.dart';
import 'package:discuss_it/models/Global.dart';
import 'package:discuss_it/models/providers/Movies.dart';
import 'package:flutter/material.dart';

class Track {
  late int currentEp;
  late int currentSeason;
  late int nextEp;
  late int nextSeason;
  Track(
      {this.currentEp = 0,
      this.currentSeason = 0,
      this.nextEp = 0,
      this.nextSeason = 0});
}

class User with ChangeNotifier {
  Map<int, Movie> _movieWatchList = {};
  Map<int, Movie> _movieWatched = {};
  Map<int, Show> _tvWatchList = {};
  Map<int, Show> _tvWatched = {};
  List<Show> _watching = [];
  Map<int, Track> track = {};

  //this used in get schedule to indicate if there is any changes which require rebuild;
  bool isChange = false;

  void addToWatchList(Object item) {
    isChange = true;
    //check if movie or show / add to watch list and update sql.
    if (item is Movie) {
      _movieWatchList[item.id] = item;
      _add(item);
    } else if (item is Show) {
      _tvWatchList[item.id] = item;
      _add(item);
    } else if (item is Episode) {
      //episode extract the show from data base
      Show show = DataProvider.dataDB[item.id]! as Show;
      addToWatchList(show);
    }
    notifyListeners();
  }

//start watching a series
  void startWatching(int id) {
    isChange = true;
    // add to watching / update in sql to -1 and update episodes / remove from wl
    _watching.add(_tvWatchList[id]!);
    _updateEpisode(id, 1, 1);
    _update(id, -1, DataType.tvShow);
    _tvWatchList.remove(id);
    notifyListeners();
  }

//watch complete toggle for movie or show
  void watchComplete(int id) {
    if (Global.isMovie()) {
      //if id exists in watched then move it to watch list otherwise remove it
      if (_movieWatched[id] != null) {
        final item = _movieWatched[id];
        _movieWatched.remove(id);
        _movieWatchList[id] = item!;
        _update(id, 0, DataType.movie);
      } else {
        _movieWatched[id] = _movieWatchList[id]!;
        _movieWatchList.remove(id);
        _update(id, 1, DataType.movie);
      }
    } else {
      if (_tvWatched[id] != null) {
        final item = _tvWatched[id];
        _tvWatched.remove(id);
        _tvWatchList[id] = item!;
        _update(id, 0, DataType.tvShow);
      } else if (_tvWatchList[id] != null) {
        _tvWatched[id] = _tvWatchList[id]!;
        _tvWatchList.remove(id);
        _update(id, 1, DataType.tvShow);
      } else {
        //if currently watching move to next episode
        final nextEp = track[id]!.nextEp;
        final nextSeason = track[id]!.nextSeason;
        track[id]!.currentEp = nextEp;
        track[id]!.currentSeason = nextSeason;
        _updateEpisode(id, nextEp, nextSeason);
      }
    }
    notifyListeners();
  }

//delete item called when swipe the card in watch list screen
  void deleteItem(int id) {
    isChange = true;
    //delete data from everywhere
    if (Global.isMovie()) {
      _movieWatched.remove(id);
      removeFromWatchList(id);
    } else {
      _tvWatched.remove(id);
      _watching.remove(id);
      removeFromWatchList(id);
    }
  }

//helper methods

  void updateNext(int id, int season, int episode) {
    if (track[id] == null) {
      track[id] =
          Track(currentEp: 1, currentSeason: 1, nextEp: episode, nextSeason: 1);
    } else {
      track[id]!.nextSeason = season;
      track[id]!.nextEp = episode;
    }
  }

  void removeFromWatchList(int id) {
    isChange = true;
    if (Global.isMovie()) {
      _movieWatchList.remove(id);
      _delete(id, DataType.movie);
    } else {
      _tvWatchList.remove(id);
      _delete(id, DataType.tvShow);
    }
    notifyListeners();
  }

  void removeFromWatched(int id) {
    isChange = true;
    if (Global.isMovie()) {
      _movieWatched.remove(id);
      _delete(id, DataType.movie);
    } else {
      _tvWatched.remove(id);
      _delete(id, DataType.tvShow);
    }
    notifyListeners();
  }

  void removeFromWatching(int id) {
    isChange = true;

    _watching.removeWhere((element) => element.id == id);
    _delete(id, DataType.tvShow);

    notifyListeners();
  }

  Map<int, Data> watchingtoMap() {
    Map<int, Data> map = {};

    _watching.forEach((element) {
      map[element.id] = element;
    });
    return map;
  }

  Status getStatus(int id) {
    if (_movieWatchList[id] != null || _tvWatchList[id] != null)
      return Status.watchList;
    else if (_movieWatched[id] != null || _tvWatched[id] != null)
      return Status.watched;
    else if (isWatching(id)) return Status.watching;
    return Status.none;
  }

  bool isWatching(int id) {
    for (var show in _watching) {
      if (show.id == id) return true;
    }
    return false;
  }

//sql methods
  void moveToWatched(int id) {
    Show show = _watching.firstWhere((element) => element.id == id);
    _tvWatched[id] = show;
    _watching.remove(show);
    _update(id, 1, DataType.tvShow);
  }

  void _updateEpisode(int id, int nextEps, int nextSeason) async {
    await MyApp.db!.update(
        'ShowWatch', {'currentEps': nextEps, 'currentSeason': nextSeason},
        where: 'id = $id');
  }

  void _add(Data data) async {
    if (data is Movie) {
      await MyApp.db!.transaction((txn) async {
        await txn.insert('MovieWatch', data.toMap());
      });
    } else {
      Show show = data as Show;
      await MyApp.db!.transaction((txn) async {
        await txn.insert('ShowWatch', show.toMap());
      });
    }
  }

  void _update(int id, int value, DataType type) async {
    if (type == DataType.movie)
      await MyApp.db!
          .update('MovieWatch', {'watched': value}, where: 'id = $id');
    else
      await MyApp.db!
          .update('ShowWatch', {'watched': value}, where: 'id = $id');
  }

  void _delete(int id, DataType type) async {
    if (type == DataType.movie)
      await MyApp.db!.delete('MovieWatch', where: 'id = $id');
    else
      await MyApp.db!.delete('ShowWatch', where: 'id = $id ');
  }

//getters
  Map<int, Movie> get movieWatchList {
    return {..._movieWatchList};
  }

  Map<int, Movie> get watchedMovies {
    return {..._movieWatched};
  }

  Map<int, Show> get showWatchList {
    return {..._tvWatchList};
  }

  Map<int, Show> get watchedShows {
    return {..._tvWatched};
  }

  List<Show> getCurrentlyWatching() {
    return [..._watching];
  }

//setters
  void setMovieWatchList(Map<int, Movie> movieWl) {
    _movieWatchList = {...movieWl};
  }

  void setMovieWatchedList(Map<int, Movie> watched) {
    _movieWatched = {...watched};
  }

  void setTvWatchList(Map<int, Show> tvWL) {
    _tvWatchList = {...tvWL};
  }

  void setTvWatchedList(Map<int, Show> tvWatched) {
    _tvWatched = {...tvWatched};
  }

  void setTrack(Map<int, Track> trak) {
    track = {...trak};
  }

  void setWatching(List<Show> wtching) {
    _watching = [...wtching];
  }
}
