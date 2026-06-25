import { createMMKV } from 'react-native-mmkv';

// react-native-mmkv v4 removed the `new MMKV()` class constructor — instances are
// now created via the createMMKV() factory. `MMKV` is a type-only export in v4.
export const storage = createMMKV({ id: 'lobotomy' });
