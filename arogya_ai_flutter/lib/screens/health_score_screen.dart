import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class HealthScoreScreen extends StatefulWidget {
  const HealthScoreScreen({super.key});

  @override
  State<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends State<HealthScoreScreen> {
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _heightController = TextEditingController(text: '175');

  double _sleepHours = 7.0;
  double _waterLiters = 2.0;
  String _activityLevel = 'Moderate';

  double _bmi = 22.86;
  int _healthScore = 82;
  String _riskLevel = 'Low Risk';
  Color _riskColor = Colors.green;

  void _calculateScore() {
    final double? weight = double.tryParse(_weightController.text);
    final double? height = double.tryParse(_heightController.text);

    if (weight == null || height == null || height == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid height and weight values.')),
      );
      return;
    }

    // BMI = weight (kg) / height^2 (m^2)
    final double heightInMeters = height / 100;
    final double calculatedBmi = weight / (heightInMeters * heightInMeters);

    // Score deduction starting from 100
    double score = 100;

    // 1. BMI Penalty
    if (calculatedBmi < 18.5) {
      score -= 15; // Underweight
    } else if (calculatedBmi >= 25 && calculatedBmi < 30) {
      score -= 10; // Overweight
    } else if (calculatedBmi >= 30) {
      score -= 20; // Obese
    }

    // 2. Sleep Penalty
    if (_sleepHours < 6) {
      score -= 15;
    } else if (_sleepHours < 7) {
      score -= 5;
    }

    // 3. Water Penalty
    if (_waterLiters < 2) {
      score -= 10;
    }

    // 4. Activity Penalty
    if (_activityLevel == 'Sedentary') {
      score -= 15;
    } else if (_activityLevel == 'Light') {
      score -= 5;
    }

    // Set Risk Level
    String risk;
    Color color;
    if (score >= 80) {
      risk = 'Low Risk';
      color = const Color(0xFF10B981);
    } else if (score >= 60) {
      risk = 'Medium Risk';
      color = const Color(0xFFF59E0B);
    } else {
      risk = 'High Risk';
      color = const Color(0xFFEF4444);
    }

    setState(() {
      _bmi = calculatedBmi;
      _healthScore = score.clamp(10, 100).toInt();
      _riskLevel = risk;
      _riskColor = color;
    });
  }

  List<String> _getSuggestions() {
    List<String> suggestions = [];
    if (_bmi < 18.5) suggestions.add("Increase nutrient-dense caloric intake with clean protein.");
    if (_bmi >= 25) suggestions.add("Incorporate 150 minutes of weekly cardio to normalize BMI.");
    if (_sleepHours < 7) suggestions.add("Prioritize 7-8 hours of continuous night sleep.");
    if (_waterLiters < 3) suggestions.add("Increase daily water intake to 3 liters.");
    if (_activityLevel == 'Sedentary') suggestions.add("Begin with a 15-minute daily brisk walk.");
    if (suggestions.isEmpty) {
      suggestions.add("Outstanding job! Keep up your healthy lifestyle choices.");
    }
    return suggestions;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Health Score Monitor', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Circular Score Widget
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: _healthScore / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey[200],
                            color: _riskColor,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$_healthScore',
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                            ),
                            const Text('Health Score', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox('BMI', _bmi.toStringAsFixed(1), Colors.blue),
                        _buildStatBox('Risk status', _riskLevel, _riskColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // BMI Inputs
            FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BMI Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lifestyle Inputs
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lifestyle Habits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    // Sleep Slider
                    Text('Sleep Hours: ${_sleepHours.toInt()} hrs', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _sleepHours,
                      min: 4,
                      max: 10,
                      divisions: 6,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => setState(() => _sleepHours = val),
                    ),
                    // Water Slider
                    Text('Water Intake: ${_waterLiters.toInt()} Liters', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _waterLiters,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => setState(() => _waterLiters = val),
                    ),
                    // Activity dropdown
                    const Text('Physical Activity Level', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _activityLevel,
                      items: ['Sedentary', 'Light', 'Moderate', 'Active']
                          .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _activityLevel = val);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Calculate Button
            ElevatedButton(
              onPressed: _calculateScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Calculate Health Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            // Heuristic Recommendations
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lightbulb, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Health Recommendations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0369A1))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._getSuggestions().map(
                      (sug) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0369A1))),
                            Expanded(child: Text(sug, style: const TextStyle(color: Color(0xFF0C4A6E), fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
