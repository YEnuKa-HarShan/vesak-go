import 'package:flutter/material.dart';

class PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  final double duration;

  const PulseDot({
    super.key,
    this.size = 20,
    this.color = Colors.blue,
    this.duration = 2,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration.toInt()),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: Container(
            width: widget.size * _scaleAnimation.value,
            height: widget.size * _scaleAnimation.value,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(_opacityAnimation.value),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
