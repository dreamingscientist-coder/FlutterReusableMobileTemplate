import tempfile
import unittest
from pathlib import Path
from sync_store_links import apple_links, merge_links, synchronize, read_defaults


class StoreDiscoveryTest(unittest.TestCase):
    def test_lookup_requires_matching_bundle(self):
        record = {'bundleId': 'other.app', 'trackId': 123}
        with self.assertRaises(ValueError):
            apple_links('my.app', '123', fetch=lambda _: {'results': [record]})

    def test_public_urls_come_from_listing_without_tracking(self):
        record = {'bundleId': 'my.app', 'trackId': 123,
                  'trackViewUrl': 'https://apps.apple.com/fr/app/my-app/id123?uo=4',
                  'artistViewUrl': 'https://apps.apple.com/fr/developer/my-name/id456?uo=4'}
        links = apple_links('my.app', '123', fetch=lambda _: {'results': [record]})
        self.assertEqual(links['appleAppUrl'], 'https://apps.apple.com/fr/app/my-app/id123')
        self.assertNotIn('?', links['appleDeveloperUrl'])

    def test_fill_blanks_but_require_confirmation_for_replacement(self):
        calls = []
        def decline(*args):
            calls.append(args)
            return False
        found = {'appleAppUrl': 'new', 'appleDeveloperUrl': 'developer'}
        result = merge_links({'appleAppUrl': 'old', 'appleDeveloperUrl': ''}, found, decline)
        self.assertEqual(result, {'appleAppUrl': 'old', 'appleDeveloperUrl': 'developer'})
        self.assertEqual(len(calls), 1)
        self.assertEqual(merge_links(result, found, lambda *_: True), found)

    def test_formatted_multiline_defaults_are_not_treated_as_empty(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            service = root / 'lib/services/store_links.dart'
            service.parent.mkdir(parents=True)
            service.write_text('class StoreLinks {}')
            service.with_name('store_links_config.dart').write_text(
                "class StoreLinksConfig { static const appleAppUrl =\n"
                "    'https://apps.apple.com/fr/app/my-app/id123'; }")
            self.assertEqual(read_defaults(root)[2]['appleAppUrl'],
                             'https://apps.apple.com/fr/app/my-app/id123')

    def test_saves_compiled_defaults_preserves_other_defines_and_declines_conflict(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            service = root / 'lib/services/store_links.dart'
            service.parent.mkdir(parents=True)
            service.write_text('class StoreLinks { const StoreLinks({\n' +
                '\n'.join("this." + field + " = const String.fromEnvironment('KEY'),"
                          for field in ('appleAppUrl', 'googleAppUrl', 'appleDeveloperUrl', 'googleDeveloperUrl')) + '\n}); }')
            define = root / 'admob_ios_defines.json'
            define.write_text('{"APPLE_APP_STORE_URL":"https://apps.apple.com/app/id999", "UNRELATED":"preserve"}')
            url = 'https://apps.apple.com/fr/app/my-app/id123'
            synchronize(root, {'appleAppUrl': url}, lambda *_: False)
            self.assertIn(url, service.with_name('store_links_config.dart').read_text())
            self.assertIn('StoreLinksConfig.appleAppUrl', service.read_text())
            self.assertIn('id999', define.read_text())
            self.assertIn('preserve', define.read_text())
            synchronize(root, {'appleAppUrl': url}, lambda *_: True)
            self.assertIn('id123', define.read_text())
            self.assertTrue(define.with_suffix('.json.bak').exists())


if __name__ == '__main__':
    unittest.main()
