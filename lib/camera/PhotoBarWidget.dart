import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class PhotoItem
{
    File? file;
}


abstract class PhotoBarWidgetListener
{
    void onPhotoItemSelected(PhotoItem item);
}


class PhotoBarWidget extends StatefulWidget
{
    late _PhotoBarState _state;
    List<PhotoItem> photos = [];

    void addPhoto(File file)
    {
        var photo = PhotoItem();
        photo.file = file;
        this.photos.add(photo);

        _state.setState(() {
        });
    }

    int? _selectedIndex;
    int? get selectedIndex => _selectedIndex;
    set selectedIndex(int? index)
    {
        _state.setState(() {
          _selectedIndex = index;
        });
    }

    WeakReference<PhotoBarWidgetListener>? _listener;
    set listener(PhotoBarWidgetListener listener)
    {
        _listener = WeakReference(listener);
    }

    @override
    State<StatefulWidget> createState() {
        _state = _PhotoBarState();
        return _state;
    }
}


class _PhotoBarState extends State<PhotoBarWidget>
{
    @override
    Widget build(BuildContext context)
    {
        return SizedBox(
            width: double.infinity,
            height: _getItemSize(context),
            child:
            Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child:
                GridView(
                    scrollDirection: Axis.horizontal,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: _getItemSize(context),
                        mainAxisSpacing: ITEM_PADDING,
                        crossAxisSpacing: ITEM_PADDING,
                        childAspectRatio:  1 //宽高比为1时，子widget
                    ),
                    //physics: NeverScrollableScrollPhysics(), // disable scrollable
                    shrinkWrap: true,
                    children: this.widget.photos.mapIndexed((i, item) => _getItemContainer(item, i)).toList())
                ));
    }

    Widget _getItemContainer(PhotoItem item, int index)
    {
        final container = Container(
                                    padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                                    alignment: Alignment.center,
                                    child:
                                    Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            image:
                                                item.file != null ?
                                                DecorationImage(image: FileImage(item.file!), fit: BoxFit.cover)
                                                : null,
                                            border: Border.all(
                                                color: this.widget._selectedIndex == index ? Colors.cyan : Colors.transparent,
                                                width: 3.5),
                                            borderRadius: BorderRadius.all(Radius.circular(18.0),
                                            ),
                                        )
                                    ));

        var gesture = GestureDetector(
                                onTap: () {
                                    setState(() {
                                        this.widget.selectedIndex = index;
                                        this.widget._listener?.target?.onPhotoItemSelected(item);
                                    });
                                },
                                child: container
                            );

        return gesture;
    }

    double _itemWidth = 0;
    final double ITEM_PADDING = 0;
    final int ITEM_COUNT = 4;

    double _getItemSize(BuildContext context)
    {
        if (_itemWidth > 0)
        {
            return _itemWidth;
        }

        var width = MediaQuery.of(context).size.width;
        width -= ITEM_PADDING * (ITEM_COUNT - 1);
        _itemWidth = width / ITEM_COUNT;

        return _itemWidth;
    }
}