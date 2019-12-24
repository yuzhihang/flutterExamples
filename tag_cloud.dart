import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class Point {
  double x, y, z;
  Color color;

  Point(this.x, this.y, this.z, {this.color = Colors.white});
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '标签云',
      theme: ThemeData(
          primarySwatch: Colors.blue, scaffoldBackgroundColor: Colors.black),
      home: MyHomePage(title: '标签云'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double rpm = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child:
            Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(builder: (context, constraints) {
              return TagCloud(constraints.maxWidth, constraints.maxHeight,
                  rpm: this.rpm);
            }),
          ),
          Text(
            '滑动球体可以改变转动方向\n滑动条可以改变转动速度',
            style: TextStyle(color: Colors.white, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          Container(
            color: Colors.white,
            child: Slider(
                value: this.rpm,
                min: 0,
                max: 10,
                onChanged: (value) {
                  setState(() {
                    print(value);
                    this.rpm = value;
                  });
                }),
          ),
        ]),
      ),
    );
  }
}

class TagCloud extends StatefulWidget {
  final double width, height, rpm; //rpm 每分钟圈数

  TagCloud(this.width, this.height, {this.rpm = 3});

  @override
  _TagCloudState createState() => _TagCloudState();
}

class _TagCloudState extends State<TagCloud>
    with SingleTickerProviderStateMixin {
  Animation<double> rotationAnimation;
  AnimationController animationController;
  int intervals = 20;
  List<Point> points;
  int pointsCount = 20;
  Timer t;
  double radius, tagRadius, angleDelta, prevAngle = 0.0;
  Point rotateAxis = Point(0, 1, 0); //初始为Y轴

  @override
  void initState() {
    super.initState();
    radius = widget.width / 2;
    points = _generateInitialPoints();
    animationController = new AnimationController(
      vsync: this,
      duration: Duration(seconds: 60 ~/ widget.rpm),
    );
    rotationAnimation =
        Tween(begin: 0.0, end: pi * 2).animate(animationController)
          ..addListener(() {
            setState(() {
              var angle = rotationAnimation.value;
              angleDelta = angle - prevAngle;
              prevAngle = angle;
              _rotatePoints(points, rotateAxis, angleDelta);
            });
          });
    animationController.repeat();
  }

  @override
  didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      animationController.duration = Duration(seconds: 60 ~/ widget.rpm);
      if (animationController.isAnimating) animationController.repeat();
    });
  }

  _stopAnimation() {
    if (animationController.isAnimating)
      animationController.stop();
    else {
      animationController.repeat();
    }
  }

  _generateInitialPoints() {
    //生产初始点
    var floatingOffset = 15; //漂浮距离，越大漂浮感越强
    var radius = widget.width / 2 + floatingOffset;
    List<Point> points = [];
    for (var i = 0; i < pointsCount; i++) {
      double x =
          1 * Random().nextDouble() * (Random().nextBool() == true ? 1 : -1);
      double remains = sqrt(1 - x * x);

      double y = remains *
          Random().nextDouble() *
          (Random().nextBool() == true ? 1 : -1);

      double z =
          sqrt(1 - x * x - y * y) * (Random().nextBool() == true ? 1 : -1);

      points.add(new Point(x * radius, y * radius, z * radius,
          color: Color.fromRGBO(
            (x.abs() * 256).ceil(),
            (y.abs() * 256).ceil(),
            (z.abs() * 256).ceil(),
            1,
          )));
    }

    return points;
  }

  _rotatePoints(List<Point> points, Point axis, double angle) {
    //罗德里格旋转矢量公式
    //计算点 x,y,z 绕轴axis转动angle角度后的新坐标

    //预先缓存不变值，如sin，cos等，避免重复计算
    var a = axis.x,
        b = axis.y,
        c = axis.z,
        a2 = a * a,
        b2 = b * b,
        c2 = c * c,
        ab = a * b,
        ac = a * c,
        bc = b * c,
        sinA = sin(angle),
        cosA = cos(angle);
    points.forEach((point) {
      var x = point.x, y = point.y, z = point.z;
      point.x = (a2 + (1 - a2) * cosA) * x +
          (ab * (1 - cosA) - c * sinA) * y +
          (ac * (1 - cosA) + b * sinA) * z;
      point.y = (ab * (1 - cosA) + c * sinA) * x +
          (b2 + (1 - b2) * cosA) * y +
          (bc * (1 - cosA) - a * sinA) * z;
      point.z = (ac * (1 - cosA) - b * sinA) * x +
          (bc * (1 - cosA) + a * sinA) * y +
          (c2 + (1 - c2) * cosA) * z;
    });
    return points;
  }

  _buildPainter(points) {
    return CustomPaint(
      size: Size(radius * 2, radius * 2),
      painter: TagsPainter(points),
    );
  }

  _buildBody() {
    List<Widget> children = [];
    //球体，添加了边界阴影
    var sphere = Container(
        height: radius * 2,
        decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 30.0,
                  spreadRadius: 10.0),
            ]));
    children.add(sphere);
    children.add(_buildPainter(points));

    return GestureDetector(
      onPanUpdate: (dragUpdateDetails) {
        //滑动球体改变旋转轴
        var dx = dragUpdateDetails.delta.dx, dy = dragUpdateDetails.delta.dy;
        var sqrtxy = sqrt(dx * dx + dy * dy);
        rotateAxis = Point(-dy / sqrtxy, dx / sqrtxy, 0);
      },
      child: Stack(
        children: children,
      ),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }
}

class TagsPainter extends CustomPainter {
  List<Point> points;
  double radius = 16;
  double prevX = 0;
  var paintStyle = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  TagsPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.width / 2);
    points.forEach((point) {
      var opacity = _getOpacity(point.z / size.width * 2);
      paintStyle.color = point.color.withOpacity(opacity);
      var r = _getScale(point.z / size.width * 2) * radius;
      canvas.drawCircle(Offset(point.x, point.y), r, paintStyle);
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

double _getOpacity(double z) {
//  根据z坐标设置透明度, 制造距离感
  //在正面为1，背面最低0.1
  return z > 0 ? 1 : (1 + z) * 0.9 + 0.1;
}

double _getScale(double z) {
  //使用z坐标设置标签大小，制造距离感
  //从[-1,1]区间转移到[1/4,1]区间
  //背面最小时为正面1/16大小
  return z * 3 / 8 + 5 / 8;
}
