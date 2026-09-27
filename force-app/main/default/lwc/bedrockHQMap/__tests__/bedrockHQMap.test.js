import { createElement } from 'lwc';
import BedrockHQMap from 'c/bedrockHQMap';

describe('c-bedrock-h-q-map', () => {
    afterEach(() => {
        // Reset the DOM after each test so tests stay isolated
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function createComponent() {
        const element = createElement('c-bedrock-h-q-map', {
            is: BedrockHQMap
        });
        document.body.appendChild(element);
        return element;
    }

    it('renders the lightning-card with the expected title and icon', () => {
        const element = createComponent();

        const card = element.shadowRoot.querySelector('lightning-card');
        expect(card).not.toBeNull();
        expect(card.title).toBe('Bedrock Corporate Headquarters');
        expect(card.iconName).toBe('utility:location');
    });

    it('renders the lightning-map with the correct zoom level and config', () => {
        const element = createComponent();

        const map = element.shadowRoot.querySelector('lightning-map');
        expect(map).not.toBeNull();
        expect(map.zoomLevel).toBe(15);
        expect(map.markersTitle).toBe('Bedrock HQ');
        expect(map.showFooter).toBe(true);
    });

    it('passes a single HQ marker with the correct location data', () => {
        const element = createComponent();

        const map = element.shadowRoot.querySelector('lightning-map');
        expect(map.mapMarkers).toHaveLength(1);

        const marker = map.mapMarkers[0];
        expect(marker.title).toBe('Bedrock HQ');
        expect(marker.description).toBe(
            'The Landmark @ One Market, Suite 300, San Francisco, CA 94105'
        );
        expect(marker.location).toEqual({
            Street: 'The Landmark @ One Market, Suite 300',
            City: 'San Francisco',
            State: 'CA',
            PostalCode: '94105',
            Country: 'USA'
        });
    });
});
