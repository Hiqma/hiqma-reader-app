import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/authentication_service.dart';
import '../models/student.dart';
import '../screens/student_login_screen.dart';
import '../theme/app_theme.dart';

class SessionManagementWidget extends StatelessWidget {
  const SessionManagementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthenticationService>(
      builder: (context, authService, child) {
        if (!authService.isDeviceRegistered) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current session info
              Row(
                children: [
                  _buildSessionAvatar(authService),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSessionTitle(authService),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getSessionSubtitle(authService),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSessionActions(context, authService),
                ],
              ),
              
              // Student switching options
              if (authService.cachedStudents.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Switch Student',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                _buildStudentSwitcher(context, authService),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionAvatar(AuthenticationService authService) {
    if (authService.isStudentLoggedIn && authService.currentStudent != null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.accent.withOpacity(0.2),
        child: Text(
          authService.currentStudent!.initials,
          style: TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.withOpacity(0.2),
        child: const Icon(
          Icons.person_outline,
          color: Colors.grey,
          size: 24,
        ),
      );
    }
  }

  String _getSessionTitle(AuthenticationService authService) {
    if (authService.isStudentLoggedIn && authService.currentStudent != null) {
      return authService.currentStudent!.displayName;
    } else {
      return 'Anonymous User';
    }
  }

  String _getSessionSubtitle(AuthenticationService authService) {
    if (authService.isStudentLoggedIn && authService.currentStudent != null) {
      final student = authService.currentStudent!;
      final parts = <String>[];
      if (student.grade != null) parts.add('Grade ${student.grade}');
      if (student.age != null) parts.add('Age ${student.age}');
      return parts.isNotEmpty ? parts.join(' • ') : 'Student';
    } else {
      return 'Reading without student login';
    }
  }

  Widget _buildSessionActions(BuildContext context, AuthenticationService authService) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'switch':
            _showStudentLoginDialog(context);
            break;
          case 'logout':
            await authService.logoutStudent();
            break;
          case 'login':
            _showStudentLoginDialog(context);
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        
        if (authService.isStudentLoggedIn) {
          items.addAll([
            const PopupMenuItem(
              value: 'switch',
              child: Row(
                children: [
                  Icon(Icons.switch_account),
                  SizedBox(width: 8),
                  Text('Switch Student'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ]);
        } else {
          items.add(
            const PopupMenuItem(
              value: 'login',
              child: Row(
                children: [
                  Icon(Icons.login),
                  SizedBox(width: 8),
                  Text('Student Login'),
                ],
              ),
            ),
          );
        }
        
        return items;
      },
    );
  }

  Widget _buildStudentSwitcher(BuildContext context, AuthenticationService authService) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: authService.cachedStudents.length + 1, // +1 for anonymous option
        itemBuilder: (context, index) {
          if (index == 0) {
            // Anonymous option
            return _buildStudentOption(
              context,
              authService,
              null,
              'Anonymous',
              Icons.person_outline,
              authService.isAnonymousSession,
            );
          } else {
            final student = authService.cachedStudents[index - 1];
            return _buildStudentOption(
              context,
              authService,
              student,
              student.displayName,
              null,
              authService.currentStudent?.id == student.id,
            );
          }
        },
      ),
    );
  }

  Widget _buildStudentOption(
    BuildContext context,
    AuthenticationService authService,
    Student? student,
    String name,
    IconData? icon,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () async {
          if (student == null) {
            // Switch to anonymous
            await authService.logoutStudent();
          } else if (!isSelected) {
            // Switch to this student
            await authService.switchStudent(student.studentCode);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.accent : Colors.grey,
                )
              else
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isSelected 
                      ? AppTheme.accent.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  child: Text(
                    student!.initials,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: const StudentLoginScreen(isOptional: true),
        ),
      ),
    );
  }
}

/// Compact session indicator for app bars
class SessionIndicator extends StatelessWidget {
  const SessionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthenticationService>(
      builder: (context, authService, child) {
        if (!authService.isDeviceRegistered) {
          return const SizedBox.shrink();
        }

        return InkWell(
          onTap: () => _showSessionDialog(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: authService.isStudentLoggedIn
                      ? AppTheme.accent.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  child: authService.isStudentLoggedIn && authService.currentStudent != null
                      ? Text(
                          authService.currentStudent!.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        )
                      : const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 14,
                        ),
                ),
                const SizedBox(width: 6),
                Text(
                  authService.isStudentLoggedIn && authService.currentStudent != null
                      ? authService.currentStudent!.displayName
                      : 'Anonymous',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(16),
          child: const SessionManagementWidget(),
        ),
      ),
    );
  }
}