import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/core/ci_detection.dart';

void main() {
  group('isCiFromEnv', () {
    test('CI=true → detected', () {
      expect(isCiFromEnv({'CI': 'true'}), isTrue);
    });

    test('CI=1 → detected', () {
      expect(isCiFromEnv({'CI': '1'}), isTrue);
    });

    test('CI=false → not detected (no vendor envs present)', () {
      expect(isCiFromEnv({'CI': 'false'}), isFalse);
    });

    test('empty env → not detected', () {
      expect(isCiFromEnv(const {}), isFalse);
    });

    test('CI absent + unrelated env → not detected', () {
      expect(isCiFromEnv({'HOME': '/Users/dev', 'PATH': '/usr/bin'}), isFalse);
    });

    test('GITHUB_ACTIONS presence → detected', () {
      expect(isCiFromEnv({'GITHUB_ACTIONS': 'true'}), isTrue);
      expect(isCiFromEnv({'GITHUB_ACTIONS': 'whatever'}), isTrue);
    });

    test('GITLAB_CI presence → detected', () {
      expect(isCiFromEnv({'GITLAB_CI': 'true'}), isTrue);
    });

    test('CIRCLECI presence → detected', () {
      expect(isCiFromEnv({'CIRCLECI': 'true'}), isTrue);
    });

    test('BUILDKITE presence → detected', () {
      expect(isCiFromEnv({'BUILDKITE': 'true'}), isTrue);
    });

    test('TF_BUILD presence (Azure) → detected regardless of casing', () {
      expect(isCiFromEnv({'TF_BUILD': 'True'}), isTrue);
      expect(isCiFromEnv({'TF_BUILD': 'true'}), isTrue);
    });

    test('BITBUCKET_COMMIT (Bitbucket Pipelines) → detected', () {
      expect(isCiFromEnv({'BITBUCKET_COMMIT': 'abc123'}), isTrue);
    });

    test('CM_BUILD_ID (Codemagic) → detected', () {
      expect(isCiFromEnv({'CM_BUILD_ID': 'build-42'}), isTrue);
    });

    test('JENKINS_URL → detected', () {
      expect(isCiFromEnv({'JENKINS_URL': 'http://jenkins.local'}), isTrue);
    });

    test('TEAMCITY_VERSION → detected', () {
      expect(isCiFromEnv({'TEAMCITY_VERSION': '2024.03'}), isTrue);
    });

    test('TF_BUILD (Azure Pipelines) → detected', () {
      expect(isCiFromEnv({'TF_BUILD': 'True'}), isTrue);
    });

    test('bamboo_planKey → detected', () {
      expect(isCiFromEnv({'bamboo_planKey': 'PROJ-PLAN'}), isTrue);
    });

    test('CI=true wins even when conflicting vendor envs are present', () {
      expect(isCiFromEnv({'CI': 'true', 'BITBUCKET_COMMIT': 'abc'}), isTrue);
    });
  });

  group('isCiEnvironment (live)', () {
    test('returns a bool without throwing', () {
      // We can't deterministically assert true or false because this test
      // can run both locally and on CI. We just verify the getter is
      // wired correctly to Platform.environment.
      expect(isCiEnvironment, isA<bool>());
    });
  });
}
