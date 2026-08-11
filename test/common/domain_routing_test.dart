import 'package:flclashx/common/application_routing.dart';
import 'package:flclashx/common/domain_routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const profileId = 'profile';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps an independent location for every domain', () async {
    await DomainRoutingStore.set(
      profileId,
      const DomainRouteEntry(
        domain: 'youtube.com',
        route: ApplicationRoute.proxy,
        target: 'Netherlands',
      ),
    );
    await DomainRoutingStore.set(
      profileId,
      const DomainRouteEntry(
        domain: 'pornhub.com',
        route: ApplicationRoute.proxy,
        target: 'Germany',
      ),
    );

    expect(await DomainRoutingStore.clashRules(profileId), [
      'DOMAIN-SUFFIX,youtube.com,Netherlands',
      'DOMAIN-SUFFIX,pornhub.com,Germany',
    ]);
  });

  test('changing one site does not replace another site route', () async {
    await DomainRoutingStore.set(
      profileId,
      const DomainRouteEntry(
        domain: 'youtube.com',
        route: ApplicationRoute.proxy,
        target: 'Netherlands',
      ),
    );
    await DomainRoutingStore.set(
      profileId,
      const DomainRouteEntry(
        domain: 'pornhub.com',
        route: ApplicationRoute.proxy,
        target: 'Germany',
      ),
    );
    await DomainRoutingStore.set(
      profileId,
      const DomainRouteEntry(
        domain: 'https://www.youtube.com/watch?v=example',
        route: ApplicationRoute.proxy,
        target: 'Japan',
      ),
    );

    expect(await DomainRoutingStore.clashRules(profileId), [
      'DOMAIN-SUFFIX,pornhub.com,Germany',
      'DOMAIN-SUFFIX,youtube.com,Japan',
    ]);
  });

  test('site rules can carve an exception out of a browser route', () async {
    await ApplicationRoutingStore.set(
      profileId,
      const ApplicationRouteEntry(
        executablePath: r'C:\Program Files\Browser\browser.exe',
        route: ApplicationRoute.proxy,
        target: 'India',
      ),
    );
    await DomainRoutingStore.set(
      profileId,
      const DomainRouteEntry(
        domain: 'youtube.com',
        route: ApplicationRoute.proxy,
        target: 'Netherlands',
      ),
    );

    final rules = [
      ...await DomainRoutingStore.clashRules(profileId),
      ...await ApplicationRoutingStore.clashRules(profileId),
    ];

    expect(rules, [
      'DOMAIN-SUFFIX,youtube.com,Netherlands',
      r'PROCESS-PATH,C:\Program Files\Browser\browser.exe,India',
    ]);
  });

  test('a saved domain also covers its subdomains after refresh', () {
    const route = DomainRouteEntry(
      domain: 'example.com',
      route: ApplicationRoute.proxy,
      target: 'Netherlands',
    );

    expect(
      DomainRoutingStore.find(const [route], 'https://music.example.com/play'),
      same(route),
    );
    expect(DomainRoutingStore.find(const [route], 'notexample.com'), isNull);
  });
}
